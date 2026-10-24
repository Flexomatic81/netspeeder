// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// Runs the project's checks, the same ones CI runs.
//
//   node tools/check.mjs                  every step
//   node tools/check.mjs fast             eslint, format and test (what the pre-commit hook runs)
//   node tools/check.mjs qmllint test     single steps, in the order given
//   node tools/check.mjs --install-hook   run the fast checks before every commit
//
// Only the Node standard library is used. qmllint, smoke and load need Qt or a desktop session: locally a
// missing tool skips them, in CI a missing tool fails the run. The Node tools are never skipped.

import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const STEPS = ["eslint", "format", "test", "qmllint", "shellcheck", "smoke", "load"];
export const GROUPS = { fast: ["eslint", "format", "test"] };
export const LOCAL_ONLY = ["smoke", "load"];
export const QT_STEPS = ["qmllint"];
export const COVERAGE = { lines: 98, branches: 98, functions: 100 };
export const PLUGIN_ID = "io.github.flexomatic81.netspeeder";
const QT_DIRS = ["/usr/lib/qt6/bin", "/usr/lib64/qt6/bin"]; // Arch/Debian/Ubuntu, Fedora
const PINS_FILE = path.join(ROOT, "tools", "requirements-dev.txt");
const INSTALL_HINT = "install the development tools with: pnpm install";
const CODE_DIR = "package/contents/code";

/** Step and group names to steps in the order given, each once; no names means every step. */
export function selectSteps(args) {
  if (args.length === 0) return [...STEPS];
  const out = [];
  for (const arg of args) {
    const names = GROUPS[arg] ?? (STEPS.includes(arg) ? [arg] : null);
    if (!names) {
      throw new Error(`unknown step: ${arg} (steps: ${STEPS.join(", ")}; groups: ${Object.keys(GROUPS).join(", ")})`);
    }
    out.push(...names.filter((n) => !out.includes(n)));
  }
  return out;
}

/** "name==version" lines to { name: version }; comments and blank lines are skipped, anything else is an error. */
export function readPins(text) {
  const pins = {};
  for (const raw of text.split("\n")) {
    const line = raw.split("#")[0].trim();
    if (!line) continue;
    const [name, version] = line.split("==");
    if (!name?.trim() || !version?.trim()) throw new Error(`not an exact pin: ${raw}`);
    pins[name.trim().toLowerCase()] = version.trim();
  }
  return pins;
}

/** The first version number in the output has major version 6 ("qmllint 6.12.0", not "qmllint 5.15.3"). */
export function isQt6(versionOutput) {
  const match = /(?<![\d.])(\d+)\.\d+/.exec(versionOutput);
  return match !== null && match[1] === "6";
}

/** The Qt 6 qmllint: Qt's own bin directories first, then the names distributions put on PATH, then a plain one
 *  that reports Qt 6 (a plain one may be Qt 5's, which knows no --max-warnings). */
function findQmllint(env) {
  const own = env.qtDirs.map((dir) => path.join(dir, "qmllint")).find((file) => env.isFile(file));
  if (own) return own;
  const named = ["qmllint6", "qmllint-qt6"].map((n) => env.which(n)).find(Boolean);
  if (named) return named;
  const plain = env.which("qmllint");
  return plain && isQt6(env.qtVersion?.(plain) ?? "") ? plain : null;
}

function testCommand(env) {
  const tests = env.testFiles();
  const { lines, branches, functions } = COVERAGE;
  return [
    process.execPath,
    "--test",
    "--experimental-test-coverage",
    `--test-coverage-include=${CODE_DIR}/**`,
    `--test-coverage-lines=${lines}`,
    `--test-coverage-branches=${branches}`,
    `--test-coverage-functions=${functions}`,
    ...tests,
  ];
}

function shellcheckCommand(env) {
  const prefix = env.which("uvx")
    ? ["uvx", "--from", `shellcheck-py==${env.pins["shellcheck-py"]}`, "shellcheck"]
    : [env.which("shellcheck")];
  if (!prefix[0]) return null;
  return [...prefix, ...env.gitFiles(["*.sh"]), "tools/hooks/pre-commit"];
}

function qmllintCommand(env) {
  const qmllint = findQmllint(env);
  // qmllint exits 0 on warnings unless told otherwise.
  const files = env.gitFiles(["package", "tests/qml"]).filter((f) => f.endsWith(".qml"));
  if (qmllint && files.length === 0) throw new Error("no QML files found to lint");
  return qmllint ? [qmllint, "--max-warnings", "0", ...files] : null;
}

const PLANNERS = {
  eslint: { tool: "eslint", command: () => ["pnpm", "exec", "eslint", "."], needs: "pnpm" },
  format: { tool: "prettier", command: () => ["pnpm", "exec", "prettier", "--check", "**/*.mjs"], needs: "pnpm" },
  test: { tool: "node", command: testCommand },
  qmllint: { tool: "Qt 6 qmllint", command: qmllintCommand },
  shellcheck: { tool: "shellcheck", command: shellcheckCommand },
  smoke: { tool: "qml6", command: () => ["scripts/smoke.sh"], needs: "qml6" },
  load: { tool: "plasmawindowed", command: () => ["scripts/load-check.sh"], needs: "plasmawindowed" },
};

/** One line for an exception, to show as the reason a step failed. */
function oneLine(error) {
  return String(error?.message ?? error).split("\n")[0];
}

/** The command of one step; null when its tool is missing. The load step carries a preflight that must pass.
 *  A planning error does not escape: the step carries it as `error` and counts as failed. */
export function planStep(name, env) {
  const planner = PLANNERS[name];
  if (!planner) throw new Error(`unknown step: ${name}`);
  const present = !planner.needs || Boolean(env.which(planner.needs));
  const step = { name, command: null, missing: planner.tool, cwd: ROOT };
  try {
    if (present) step.command = planner.command(env);
  } catch (e) {
    step.error = oneLine(e);
  }
  if (name === "load") step.preflight = () => checkInstalled(env);
  return step;
}

/** "run" when the command exists; a missing one is "skipped" locally for Qt and local-only steps, else "failed".
 *  Local-only steps are skipped in CI and without a desktop session, never "passed". */
export function classify(step, env) {
  if (step.error) return "failed";
  if (LOCAL_ONLY.includes(step.name) && (env.inCi || !env.hasDesktop)) return "skipped";
  if (step.command) return "run";
  const mayBeMissing = QT_STEPS.includes(step.name) || LOCAL_ONLY.includes(step.name);
  return mayBeMissing && !env.inCi ? "skipped" : "failed";
}

/** Relative paths of all files under dir, skipping the paths in `exclude` (relative to dir). */
export function listFiles(dir, exclude = []) {
  const out = [];
  const walk = (rel) => {
    for (const entry of fs.readdirSync(path.join(dir, rel), { withFileTypes: true })) {
      const next = path.join(rel, entry.name);
      if (exclude.includes(next)) continue;
      if (entry.isDirectory()) walk(next);
      else out.push(next);
    }
  };
  walk("");
  return out.sort();
}

/** Differences between two trees: files missing on either side and files with other content. */
export function diffTrees(expectedDir, actualDir, exclude = []) {
  const expected = listFiles(expectedDir, exclude);
  const actual = new Set(listFiles(actualDir, exclude));
  const problems = [];
  for (const file of expected) {
    if (!actual.has(file)) problems.push(`missing: ${file}`);
    else if (!fs.readFileSync(path.join(expectedDir, file)).equals(fs.readFileSync(path.join(actualDir, file)))) {
      problems.push(`differs: ${file}`);
    }
  }
  const known = new Set(expected);
  return [...problems, ...[...actual].filter((f) => !known.has(f)).map((f) => `extra: ${f}`)];
}

/** null when the installed copy equals package/ (ignoring the compiled translations), else the reason. */
function checkInstalled(env) {
  if (!env.installedDir || !fs.existsSync(env.installedDir)) return `not installed: run scripts/dev-install.sh`;
  const problems = diffTrees(path.join(ROOT, "package"), env.installedDir, [path.join("contents", "locale")]);
  return problems.length === 0 ? null : `the installed copy is outdated (${problems[0]}): run scripts/dev-install.sh`;
}

function which(name, pathVar = process.env.PATH ?? "") {
  for (const dir of pathVar.split(path.delimiter).filter(Boolean)) {
    const file = path.join(dir, name);
    try {
      fs.accessSync(file, fs.constants.X_OK);
      if (fs.statSync(file).isFile()) return file;
    } catch {
      // not in this directory
    }
  }
  return null;
}

function gitFiles(patterns) {
  return execFileSync("git", ["ls-files", ...patterns], { cwd: ROOT, encoding: "utf8" })
    .split("\n")
    .filter(Boolean);
}

function qtVersion(tool) {
  try {
    return execFileSync(tool, ["--version"], { encoding: "utf8", timeout: 10000 });
  } catch {
    return "";
  }
}

function detectEnv() {
  const inCi = Boolean(process.env.CI);
  return {
    inCi,
    // CI installs shellcheck-py with pip; uvx is only used for local runs.
    which: (name) => (inCi && name === "uvx" ? null : which(name)),
    qtDirs: QT_DIRS,
    isFile: (file) => fs.existsSync(file) && fs.statSync(file).isFile(),
    pins: readPins(fs.readFileSync(PINS_FILE, "utf8")),
    qtVersion,
    gitFiles,
    testFiles: () =>
      fs
        .readdirSync(path.join(ROOT, "tests"))
        .filter((f) => f.endsWith(".test.mjs"))
        .sort()
        .map((f) => `tests/${f}`),
    hasDesktop: Boolean(process.env.DBUS_SESSION_BUS_ADDRESS),
    installedDir: path.join(os.homedir(), ".local", "share", "plasma", "plasmoids", PLUGIN_ID),
  };
}

function skipReason(step, env) {
  if (LOCAL_ONLY.includes(step.name) && env.inCi) return "local only";
  if (LOCAL_ONLY.includes(step.name) && !env.hasDesktop) return "no desktop session";
  return `${step.missing} not found`;
}

function execute(step) {
  const reason = step.preflight?.();
  if (reason) {
    console.error(reason);
    return 127;
  }
  const [cmd, ...args] = step.command;
  const result = spawnSync(cmd, args, { cwd: step.cwd, stdio: "inherit" });
  if (result.error) console.error(`${cmd}: ${result.error.message}`);
  return result.error ? 127 : (result.status ?? 1);
}

/** Result of one step; an exception while running it (for instance in the install comparison) is a failure. */
function runOne(step, run) {
  try {
    return [run(step) === 0 ? "passed" : "failed", ""];
  } catch (e) {
    return ["failed", oneLine(e)];
  }
}

/** Runs every step, also after a failure; returns { name: [passed|failed|skipped, detail] }. */
export function runSteps(steps, env, run = execute) {
  const results = {};
  for (const step of steps) {
    console.log(`\n== ${step.name} ==`);
    const verdict = classify(step, env);
    if (verdict === "run") {
      results[step.name] = runOne(step, run);
    } else if (step.error) {
      results[step.name] = ["failed", step.error];
    } else if (verdict === "skipped") {
      results[step.name] = ["skipped", skipReason(step, env)];
    } else {
      results[step.name] = ["failed", `${step.missing} not found - ${INSTALL_HINT}`];
    }
    console.log(results[step.name].filter(Boolean).join(" - "));
  }
  return results;
}

function git(...args) {
  return execFileSync("git", args, { cwd: ROOT, encoding: "utf8" }).trim();
}

/** Points git at tools/hooks, unless the hooks directory holds hooks of its own, which would stop running. */
export function installHook() {
  if (git("config", "--default", "", "core.hooksPath") === "tools/hooks") {
    console.log("The pre-commit hook is already active.");
    return 0;
  }
  const hooks = path.resolve(ROOT, git("rev-parse", "--git-path", "hooks"));
  const own = fs.existsSync(hooks)
    ? fs.readdirSync(hooks).filter((f) => !f.endsWith(".sample") && fs.statSync(path.join(hooks, f)).isFile())
    : [];
  if (own.length > 0) {
    console.error(
      `Nothing changed: ${hooks} holds hooks of its own (${own.join(", ")}) that would stop running. ` +
        "Call 'node tools/check.mjs fast' from your pre-commit hook instead.",
    );
    return 1;
  }
  git("config", "core.hooksPath", "tools/hooks");
  console.log("Pre-commit hook active: the fast checks run before every commit ('git commit --no-verify' skips them).");
  return 0;
}

export function main(argv) {
  if (argv.length === 1 && argv[0] === "--install-hook") return installHook();
  let names;
  try {
    names = selectSteps(argv);
  } catch (e) {
    console.error(e.message);
    return 2;
  }
  const env = detectEnv();
  const results = runSteps(
    names.map((n) => planStep(n, env)),
    env,
  );
  console.log("\nSummary:");
  for (const [name, [status, detail]] of Object.entries(results)) {
    console.log(`  ${name.padEnd(11)} ${status}${detail ? ` (${detail})` : ""}`);
  }
  return Object.values(results).some(([status]) => status === "failed") ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
