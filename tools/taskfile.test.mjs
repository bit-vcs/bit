import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";

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
