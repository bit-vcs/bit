import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  readFileSync,
  readdirSync,
  mkdtempSync,
  mkdirSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import path from "node:path";
import os from "node:os";
import test from "node:test";
import { loadWorkspaceModules } from "./module-publish-graph.mjs";

const taskInfo = () => {
  const result = spawnSync("pkf", ["info", "--json"], {
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
};

test("pkf test task tracks its test specifications and runners", () => {
  const task = taskInfo().tasks.find((candidate) => candidate.name === "test");
  assert.ok(task, "test task is declared");
  const inputs = task.inputs ?? [];

  for (const input of [
    "modules/**/*.mbt",
    "Test.pkl",
    "pkspec/**/*.pkl",
    "tools/**/*.mjs",
    "tools/**/*.sh",
  ]) {
    assert.ok(inputs.includes(input), `missing test input: ${input}`);
  }
});

test("Darwin native runner executes the cmd/bit suite in release mode", () => {
  const script = readFileSync("tools/test-native.sh", "utf8");

  assert.match(
    script,
    /moon test --target native --release -p mizchi\/bit\/cmd\/bit/,
  );
  assert.doesNotMatch(script, /skipping cmd\/bit whitebox shards/);
});

test("Moon test matrix selects existing workspace packages", () => {
  const packages = new Set();
  for (const module of loadWorkspaceModules()) {
    const source = path.join(module.directory, module.source ?? ".");
    const entries = readdirSync(source, { recursive: true, withFileTypes: true });
    for (const entry of entries) {
      if (entry.isFile() && ["moon.pkg", "moon.pkg.json"].includes(entry.name)) {
        const relative = path.relative(source, entry.parentPath)
          .split(path.sep).join("/");
        packages.add(relative ? `${module.name}/${relative}` : module.name);
      }
    }
  }
  const matrix = readFileSync("Test.pkl", "utf8");
  for (const [command] of matrix.matchAll(/moon test[^"\n]*/g)) {
    for (const [, selected] of command.matchAll(/-p\s+(\S+)/g)) {
      assert.ok(
        packages.has(selected),
        `test matrix selects missing package: ${selected}`,
      );
    }
    assert.doesNotMatch(
      command,
      /-f\s+\S+\.mbt\b/,
      "select test files by path, not a test-name filter",
    );
  }
});

test("layer guard rejects filesystem access in the extracted runtime module", () => {
  const root = mkdtempSync(path.join(os.tmpdir(), "bit-layer-guard-"));
  try {
    const source = path.join(root, "modules/bit_runtime/src");
    mkdirSync(source, { recursive: true });
    writeFileSync(path.join(source, "runtime.mbt"), "OsFs::new()\n");
    const result = spawnSync("bash", [path.resolve("tools/check-layer-guards.sh")], {
      cwd: root,
      encoding: "utf8",
    });
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stdout, /runtime layer must not use OsFs/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
