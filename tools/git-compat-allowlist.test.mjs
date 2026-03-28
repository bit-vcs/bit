import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

// These tests were previously excluded due to upstream oracle failures,
// but they now pass with only known breakages (TODO). Kept as reference.
// const ORACLE_BROKEN_TESTS = [
//   "t1410-reflog.sh",
//   "t3600-rm.sh",
// ];

function readAllowlistEntries(path) {
  return readFileSync(path, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith("#"));
}

test("compat allowlist has no duplicate entries", () => {
  const entries = readAllowlistEntries("tools/git-test-allowlist.txt");
  const seen = new Set();
  for (const entry of entries) {
    assert.equal(
      seen.has(entry),
      false,
      `${entry} appears more than once in tools/git-test-allowlist.txt`,
    );
    seen.add(entry);
  }
});
