import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const ORACLE_BROKEN_TESTS = [
  "t1410-reflog.sh",
  "t3600-rm.sh",
];

function readAllowlistEntries(path) {
  return readFileSync(path, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith("#"));
}

test("compat allowlist excludes known oracle-broken upstream tests", () => {
  const entries = readAllowlistEntries("tools/git-test-allowlist.txt");
  for (const testName of ORACLE_BROKEN_TESTS) {
    assert.equal(
      entries.includes(testName),
      false,
      `${testName} should stay out of tools/git-test-allowlist.txt`,
    );
  }
});
