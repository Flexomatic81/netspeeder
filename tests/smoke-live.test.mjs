// SPDX-License-Identifier: GPL-2.0-or-later
// SPDX-FileCopyrightText: 2026 Flexomatic81

// The live smoke scenes need a real network and ksystemstats. scripts/smoke.sh
// lists them so NETSPEEDER_SMOKE_SKIP_LIVE=1 can skip them; each one says so in
// its header comment. The list and the comments must agree.

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SMOKE = path.join(ROOT, "scripts", "smoke.sh");
const SCENES = path.join(ROOT, "tests", "qml");
const MARK = /^\/\/ Live scene: needs \S/;

/** The scene names in the live_scenes=( ... ) array of smoke.sh. */
function listedLive() {
  const match = /^live_scenes=\(([^)]*)\)/m.exec(fs.readFileSync(SMOKE, "utf8"));
  assert.ok(match, "smoke.sh has no live_scenes=( ... ) list");
  return match[1]
    .split("\n")
    .map((line) => line.split("#")[0].trim())
    .join(" ")
    .split(/\s+/)
    .filter(Boolean)
    .sort();
}

/** The lines of the comment block at the top of a file, up to the first other line. */
function headerComment(file) {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const end = lines.findIndex((line) => line.trim() !== "" && !line.startsWith("//"));
  return lines.slice(0, end < 0 ? lines.length : end);
}

function markedLive() {
  return fs
    .readdirSync(SCENES)
    .filter((f) => f.endsWith("Smoke.qml"))
    .filter((f) => headerComment(path.join(SCENES, f)).some((line) => MARK.test(line)))
    .sort();
}

function smoke(env, ...scenes) {
  return spawnSync("bash", [SMOKE, ...scenes], {
    cwd: ROOT,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

test("the live list of smoke.sh names exactly the scenes marked live", () => {
  const listed = listedLive();
  assert.ok(listed.length > 0);
  for (const scene of listed) {
    assert.ok(fs.existsSync(path.join(SCENES, scene)), `listed live scene ${scene} does not exist`);
  }
  assert.deepEqual(listed, markedLive());
});

test("the scenes that read the real network are among the live ones", () => {
  const listed = listedLive();
  for (const scene of ["ProcSmoke.qml", "SensorSmoke.qml", "ProviderSmoke.qml", "ConfigDataSmoke.qml"]) {
    assert.ok(listed.includes(scene), `${scene} is not in the live list`);
  }
});

test("NETSPEEDER_SMOKE_SKIP_LIVE=1 skips a live scene and says so", () => {
  const result = smoke({ NETSPEEDER_SMOKE_SKIP_LIVE: "1" }, "tests/qml/ProcSmoke.qml");
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), "SMOKE SKIPPED (live) ProcSmoke.qml");
});

test("other values of NETSPEEDER_SMOKE_SKIP_LIVE skip nothing and say so", () => {
  // A stand-in qml6 that fails at once shows that the scene ran.
  const bin = fs.mkdtempSync(path.join(os.tmpdir(), "smoke-live-"));
  try {
    fs.writeFileSync(path.join(bin, "qml6"), '#!/bin/sh\necho "ran $1"\nexit 1\n', { mode: 0o755 });
    const result = smoke(
      { NETSPEEDER_SMOKE_SKIP_LIVE: "yes", PATH: `${bin}${path.delimiter}${process.env.PATH}` },
      "tests/qml/ProcSmoke.qml",
    );
    assert.equal(result.status, 1);
    assert.doesNotMatch(result.stdout, /SKIPPED/);
    assert.match(result.stderr, /NETSPEEDER_SMOKE_SKIP_LIVE=yes is ignored/);
    assert.match(result.stderr, /ran tests\/qml\/ProcSmoke\.qml/);
  } finally {
    fs.rmSync(bin, { recursive: true, force: true });
  }
});
