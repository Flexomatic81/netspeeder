// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  COVERAGE,
  STEPS,
  classify,
  diffTrees,
  isQt6,
  planStep,
  readPins,
  runSteps,
  selectSteps,
} from "../tools/check.mjs";

function makeEnv(overrides = {}) {
  const tools = overrides.tools ?? [];
  return {
    inCi: false,
    hasDesktop: true,
    which: (name) => (tools.includes(name) ? `/usr/bin/${name}` : null),
    qtDirs: [],
    isFile: () => false,
    pins: { "shellcheck-py": "0.11.0.1" },
    qtVersion: () => "",
    gitFiles: (patterns) => (patterns.includes("*.sh") ? ["scripts/a.sh"] : ["package/x.qml", "package/y.js"]),
    testFiles: () => ["tests/a.test.mjs", "tests/b.test.mjs"],
    ...overrides,
  };
}

test("no arguments select every step", () => {
  assert.deepEqual(selectSteps([]), STEPS);
  assert.equal(STEPS.length, 7);
});

test("groups expand and every step runs once, in the order given", () => {
  assert.deepEqual(selectSteps(["fast", "eslint", "qmllint"]), ["eslint", "format", "test", "qmllint"]);
});

test("an unknown step throws and names the steps and groups", () => {
  assert.throws(() => selectSteps(["nope"]), /unknown step: nope.*eslint.*fast/);
});

test("qmllint is taken from the Qt directory with --max-warnings 0 and only the QML files", () => {
  const env = makeEnv({ qtDirs: ["/q"], isFile: (f) => f === "/q/qmllint" });
  const { command } = planStep("qmllint", env);
  assert.deepEqual(command, ["/q/qmllint", "--max-warnings", "0", "package/x.qml"]);
});

test("without a Qt directory qmllint6 from PATH is used", () => {
  const { command } = planStep("qmllint", makeEnv({ tools: ["qmllint6"] }));
  assert.equal(command[0], "/usr/bin/qmllint6");
});

test("a plain qmllint counts only when it reports Qt 6", () => {
  const qt5 = makeEnv({ tools: ["qmllint"], qtVersion: () => "qmllint 5.15.3" });
  assert.equal(planStep("qmllint", qt5).command, null);
  const qt6 = makeEnv({ tools: ["qmllint"], qtVersion: () => "qmllint 6.12.0" });
  assert.equal(planStep("qmllint", qt6).command[0], "/usr/bin/qmllint");
});

test("without any qmllint the command is null", () => {
  assert.equal(planStep("qmllint", makeEnv()).command, null);
});

test("isQt6 reads the first version number", () => {
  assert.equal(isQt6("qmllint 6.12.0"), true);
  assert.equal(isQt6("qmllint 5.6.3"), false);
  assert.equal(isQt6("nothing"), false);
});

test("a missing qmllint is skipped locally and fails in CI", () => {
  const step = planStep("qmllint", makeEnv());
  assert.equal(classify(step, makeEnv()), "skipped");
  assert.equal(classify(step, makeEnv({ inCi: true })), "failed");
});

test("a missing eslint fails locally", () => {
  const env = makeEnv();
  const step = planStep("eslint", env);
  assert.equal(step.command, null);
  assert.equal(classify(step, env), "failed");
});

test("eslint, format and test run with pnpm and node", () => {
  const env = makeEnv({ tools: ["pnpm", "node"] });
  assert.deepEqual(planStep("eslint", env).command, ["pnpm", "exec", "eslint", "."]);
  assert.deepEqual(planStep("format", env).command, ["pnpm", "exec", "prettier", "--check", "**/*.mjs"]);
  assert.equal(classify(planStep("eslint", env), env), "run");
});

test("smoke and load are skipped in CI and without a desktop session, even when runnable", () => {
  const tools = ["qml6", "plasmawindowed"];
  for (const name of ["smoke", "load"]) {
    const ci = makeEnv({ tools, inCi: true });
    assert.equal(classify(planStep(name, ci), ci), "skipped");
    const headless = makeEnv({ tools, hasDesktop: false });
    assert.equal(classify(planStep(name, headless), headless), "skipped");
    const desktop = makeEnv({ tools });
    assert.equal(classify(planStep(name, desktop), desktop), "run");
  }
});

test("the test step carries the three coverage limits and the resolved test files", () => {
  const { command } = planStep("test", makeEnv({ tools: ["node"] }));
  assert.ok(command.includes(`--test-coverage-lines=${COVERAGE.lines}`));
  assert.ok(command.includes(`--test-coverage-branches=${COVERAGE.branches}`));
  assert.ok(command.includes(`--test-coverage-functions=${COVERAGE.functions}`));
  assert.ok(command.includes("--test-coverage-include=package/contents/code/**"));
  assert.deepEqual(command.slice(-2), ["tests/a.test.mjs", "tests/b.test.mjs"]);
});

test("shellcheck runs through uvx with the pinned version when uvx exists", () => {
  const { command } = planStep("shellcheck", makeEnv({ tools: ["uvx"] }));
  assert.deepEqual(command, [
    "uvx",
    "--from",
    "shellcheck-py==0.11.0.1",
    "shellcheck",
    "scripts/a.sh",
    "tools/hooks/pre-commit",
  ]);
});

test("shellcheck falls back to PATH, and is missing without both", () => {
  assert.equal(planStep("shellcheck", makeEnv({ tools: ["shellcheck"] })).command[0], "/usr/bin/shellcheck");
  const env = makeEnv();
  const step = planStep("shellcheck", env);
  assert.equal(step.command, null);
  assert.equal(classify(step, env), "failed");
});

test("an unknown step cannot be planned", () => {
  assert.throws(() => planStep("nope", makeEnv()), /unknown step/);
});

test("readPins reads exact pins and rejects anything else", () => {
  assert.deepEqual(readPins("# c\nShellcheck-Py==0.11.0.1  # x\n\n"), { "shellcheck-py": "0.11.0.1" });
  assert.throws(() => readPins("shellcheck-py>=1"), /not an exact pin/);
});

test("runSteps runs on after a failure and never reports skipped steps as passed", () => {
  const env = makeEnv({ tools: ["pnpm"] });
  const steps = [planStep("eslint", env), planStep("qmllint", env), planStep("shellcheck", env)];
  const silent = console.log;
  console.log = () => {};
  let results;
  try {
    results = runSteps(steps, env, (step) => (step.name === "eslint" ? 1 : 0));
  } finally {
    console.log = silent;
  }
  assert.equal(results.eslint[0], "failed");
  assert.equal(results.qmllint[0], "skipped");
  assert.equal(results.shellcheck[0], "failed");
});

test("diffTrees reports missing, changed and extra files and honours the exclusion", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "check-"));
  try {
    const write = (root, file, text) => {
      fs.mkdirSync(path.dirname(path.join(dir, root, file)), { recursive: true });
      fs.writeFileSync(path.join(dir, root, file), text);
    };
    write("a", "same.txt", "1");
    write("a", "changed.txt", "1");
    write("a", "gone.txt", "1");
    write("a", "contents/locale/x.mo", "1");
    write("b", "same.txt", "1");
    write("b", "changed.txt", "2");
    write("b", "extra.txt", "1");
    const exclude = [path.join("contents", "locale")];
    assert.deepEqual(diffTrees(path.join(dir, "a"), path.join(dir, "b"), exclude), [
      "differs: changed.txt",
      "missing: gone.txt",
      "extra: extra.txt",
    ]);
    assert.deepEqual(diffTrees(path.join(dir, "a"), path.join(dir, "a"), exclude), []);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
