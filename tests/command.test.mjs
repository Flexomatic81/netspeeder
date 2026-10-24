// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { launchCommandLine, launchFailure, shellQuote } from "../package/contents/code/command.mjs";

test("shellQuote wraps in single quotes and escapes embedded ones", () => {
  assert.equal(shellQuote("it's"), "'it'\\''s'");
  assert.equal(shellQuote(""), "''");
});

test("shellQuote keeps special characters literal", () => {
  for (const text of ["a b", "$HOME", "`id`", "a;b", "a\nb", "$(id)", '"x"', "a\\b"]) {
    const result = spawnSync("sh", ["-c", `printf %s ${shellQuote(text)}`], { encoding: "utf8" });
    assert.equal(result.stdout, text);
  }
});

test("launchCommandLine accepts valid desktop ids", () => {
  const line = launchCommandLine({ kind: "app", app: "org.kde.plasma-systemmonitor" });
  assert.match(line, /^sh -c '.*' netspeeder 'org\.kde\.plasma-systemmonitor'$/s);
});

test("launchCommandLine rejects invalid desktop ids", () => {
  for (const app of ["foo bar", "a;b", "../x", ".hidden", "", undefined, "a/b", "a\n"]) {
    assert.equal(launchCommandLine({ kind: "app", app }), null, String(app));
  }
});

test("launchCommandLine rejects empty commands and unknown kinds", () => {
  assert.equal(launchCommandLine({ kind: "command", command: "   " }), null);
  assert.equal(launchCommandLine({ kind: "command", command: "" }), null);
  assert.equal(launchCommandLine({ kind: "command" }), null);
  assert.equal(launchCommandLine({ kind: "other", command: "true" }), null);
  assert.equal(launchCommandLine({}), null);
});

test("launchCommandLine passes the first word for the pre-check", () => {
  const line = launchCommandLine({ kind: "command", command: "konsole -e nethogs" });
  assert.ok(line.endsWith(" netspeeder 'konsole -e nethogs' 'konsole'"));
});

test("launchCommandLine skips the pre-check for assignments and quoted words", () => {
  for (const command of ["FOO=1 prog", '"my prog" x', "'my prog' x"]) {
    const line = launchCommandLine({ kind: "command", command });
    assert.ok(line.endsWith(` ${shellQuote(command)} ''`), command);
  }
});

test("launchFailure maps exit codes", () => {
  assert.equal(launchFailure(0), null);
  assert.equal(launchFailure(127), "not-found");
  assert.equal(launchFailure(-2), "timeout");
  assert.equal(launchFailure(1), "failed");
  assert.equal(launchFailure(-1), "failed");
});

// Execution tests: a stub setsid records its arguments, so no real program
// is ever started.
function makeSandbox() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "command-test-"));
  const bin = path.join(root, "bin");
  const data = path.join(root, "data");
  const record = path.join(root, "setsid-args");
  fs.mkdirSync(bin);
  fs.mkdirSync(path.join(data, "applications"), { recursive: true });
  const stub = path.join(bin, "setsid");
  fs.writeFileSync(stub, `#!/bin/sh\nfor a in "$@"; do printf '%s\\n' "$a" >> "${record}"; done\nexit 0\n`);
  fs.chmodSync(stub, 0o755);
  const env = {
    PATH: `${bin}:/usr/bin:/bin`,
    HOME: root,
    XDG_DATA_HOME: data,
    XDG_DATA_DIRS: path.join(root, "nothing"),
  };
  const run = (line) => {
    const result = spawnSync("sh", ["-c", line], { env, encoding: "utf8" });
    const seen = fs.existsSync(record) ? fs.readFileSync(record, "utf8").split("\n").slice(0, -1) : null;
    return { status: result.status, seen };
  };
  return { root, data, run, cleanup: () => fs.rmSync(root, { recursive: true, force: true }) };
}

test("app launch: present desktop file starts kstart detached", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  fs.writeFileSync(path.join(box.data, "applications", "demo.app.desktop"), "");
  const out = box.run(launchCommandLine({ kind: "app", app: "demo.app" }));
  assert.equal(out.status, 0);
  assert.deepEqual(out.seen, ["-f", "kstart", "--application", "demo.app"]);
});

test("app launch: missing desktop file exits 127 without starting anything", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  const out = box.run(launchCommandLine({ kind: "app", app: "missing.app" }));
  assert.equal(out.status, 127);
  assert.equal(out.seen, null);
});

test("app launch: finds desktop files in XDG_DATA_DIRS entries", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  const second = path.join(box.root, "second");
  fs.mkdirSync(path.join(second, "applications"), { recursive: true });
  fs.writeFileSync(path.join(second, "applications", "late.desktop"), "");
  const line = launchCommandLine({ kind: "app", app: "late" });
  const env = {
    PATH: `${path.join(box.root, "bin")}:/usr/bin:/bin`,
    HOME: box.root,
    XDG_DATA_HOME: box.data,
    XDG_DATA_DIRS: `${path.join(box.root, "none")}:${second}`,
  };
  const result = spawnSync("sh", ["-c", line], { env, encoding: "utf8" });
  assert.equal(result.status, 0);
});

test("command launch: existing program starts through sh -c", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  const out = box.run(launchCommandLine({ kind: "command", command: "true" }));
  assert.equal(out.status, 0);
  assert.deepEqual(out.seen, ["-f", "sh", "-c", "true"]);
});

test("command launch: unknown program exits 127 without starting anything", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  const out = box.run(launchCommandLine({ kind: "command", command: "netspeeder-gibtsnicht --x" }));
  assert.equal(out.status, 127);
  assert.equal(out.seen, null);
});

test("command launch: substitutions reach the stub unevaluated", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  const out = box.run(launchCommandLine({ kind: "command", command: "echo $(touch /nonexistent/x)" }));
  assert.equal(out.status, 0);
  assert.deepEqual(out.seen, ["-f", "sh", "-c", "echo $(touch /nonexistent/x)"]);
});

test("command launch: assignment prefix skips the pre-check", (t) => {
  const box = makeSandbox();
  t.after(box.cleanup);
  const out = box.run(launchCommandLine({ kind: "command", command: "FOO=1 netspeeder-gibtsnicht" }));
  assert.equal(out.status, 0);
  assert.deepEqual(out.seen, ["-f", "sh", "-c", "FOO=1 netspeeder-gibtsnicht"]);
});
