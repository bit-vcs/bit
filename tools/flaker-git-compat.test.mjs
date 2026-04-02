import assert from "node:assert/strict";
import test from "node:test";

import {
  GIT_COMPAT_TASK_ID,
  parseAllowlistEntries,
  listFlakerGitCompatTests,
  normalizeSelectedScripts,
  toFlakerTest,
} from "./flaker-git-compat-lib.mjs";

test("parseAllowlistEntries skips comments and blank lines", () => {
  const entries = parseAllowlistEntries(`
# comment
t1300-config.sh

 t3200-branch.sh
`);

  assert.deepEqual(entries, ["t1300-config.sh", "t3200-branch.sh"]);
});

test("toFlakerTest maps allowlist entries to flaker inventory", () => {
  assert.deepEqual(toFlakerTest("t1300-config.sh"), {
    suite: "third_party/git/t/t1300-config.sh",
    testName: "t1300-config.sh",
    taskId: GIT_COMPAT_TASK_ID,
  });
});

test("listFlakerGitCompatTests preserves allowlist order", () => {
  const tests = listFlakerGitCompatTests("tools/git-test-allowlist.txt");
  assert.equal(tests.length > 100, true);
  assert.equal(tests[0].suite.startsWith("third_party/git/t/"), true);
});

test("normalizeSelectedScripts accepts suite paths and de-duplicates", () => {
  const selected = normalizeSelectedScripts(
    [
      {
        suite: "third_party/git/t/t1300-config.sh",
        testName: "t1300-config.sh",
      },
      {
        suite: "third_party/git/t/t1300-config.sh",
        testName: "t1300-config.sh",
      },
      {
        suite: "third_party/git/t/t3200-branch.sh",
        testName: "ignored",
      },
    ],
    ["t1300-config.sh", "t3200-branch.sh"],
  );

  assert.deepEqual(selected, ["t1300-config.sh", "t3200-branch.sh"]);
});
