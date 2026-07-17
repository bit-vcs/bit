import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";

import {
  GIT_COMPAT_AFFECTED_RULES,
  renderAffectedRulesToml,
  selectSuitesForChanges,
} from "./flaker-affected-rules.mjs";

test("renderAffectedRulesToml stays in sync with committed config", () => {
  const committed = readFileSync("tools/flaker-affected-rules.toml", "utf8");
  assert.equal(renderAffectedRulesToml(GIT_COMPAT_AFFECTED_RULES), committed);
});

test("merge-related changes select merge-focused git compat suites", () => {
  const selected = selectSuitesForChanges(
    ["modules/bit/cmd/bit/merge.mbt"],
    [
      "third_party/git/t/t6400-merge-df.sh",
      "third_party/git/t/t7600-merge.sh",
      "third_party/git/t/t7508-status.sh",
    ],
    GIT_COMPAT_AFFECTED_RULES,
  );

  assert.deepEqual(selected, [
    "third_party/git/t/t6400-merge-df.sh",
    "third_party/git/t/t7600-merge.sh",
  ]);
});

test("fetch and protocol changes include transport suites", () => {
  const selected = selectSuitesForChanges(
    ["modules/bit/cmd/bit/fetch.mbt", "modules/bit_protocol/src/transport.mbt"],
    [
      "third_party/git/t/t5500-fetch-pack.sh",
      "third_party/git/t/t5700-protocol-v1.sh",
      "third_party/git/t/t1300-config.sh",
    ],
    GIT_COMPAT_AFFECTED_RULES,
  );

  assert.deepEqual(selected, [
    "third_party/git/t/t5500-fetch-pack.sh",
    "third_party/git/t/t5700-protocol-v1.sh",
  ]);
});

test("refname validation changes include branch-oriented suites", () => {
  const selected = selectSuitesForChanges(
    ["modules/bit/cmd/bit/check_ref_format.mbt"],
    [
      "third_party/git/t/t3204-branch-name-interpretation.sh",
      "third_party/git/t/t7419-submodule-set-branch.sh",
      "third_party/git/t/t7004-tag.sh",
    ],
    GIT_COMPAT_AFFECTED_RULES,
  );

  assert.deepEqual(selected, [
    "third_party/git/t/t3204-branch-name-interpretation.sh",
  ]);
});

test("tag verification changes include tag suites", () => {
  const selected = selectSuitesForChanges(
    ["modules/bit/cmd/bit/verify_tag.mbt", "modules/bit/cmd/bit/mktag_cmd.mbt"],
    [
      "third_party/git/t/t7004-tag.sh",
      "third_party/git/t/t7030-verify-tag.sh",
      "third_party/git/t/t7031-verify-tag-signed-ssh.sh",
      "third_party/git/t/t7508-status.sh",
    ],
    GIT_COMPAT_AFFECTED_RULES,
  );

  assert.deepEqual(selected, [
    "third_party/git/t/t7004-tag.sh",
    "third_party/git/t/t7030-verify-tag.sh",
    "third_party/git/t/t7031-verify-tag-signed-ssh.sh",
  ]);
});

test("module-level rule: bit_diff maps to diff suites without full run", () => {
  const selected = selectSuitesForChanges(
    ["modules/bit_diff/src/myers.mbt"],
    [
      "third_party/git/t/t4000-diff-format.sh",
      "third_party/git/t/t6427-diff3-conflict-markers.sh",
      "third_party/git/t/t7600-merge.sh",
    ],
    GIT_COMPAT_AFFECTED_RULES,
  );
  assert.deepEqual(selected, [
    "third_party/git/t/t4000-diff-format.sh",
    "third_party/git/t/t6427-diff3-conflict-markers.sh",
  ]);
});

test("foundation module changes select every suite", () => {
  const suites = [
    "third_party/git/t/t0000-basic.sh",
    "third_party/git/t/t9999-anything.sh",
  ];
  const selected = selectSuitesForChanges(
    ["modules/bit_object/src/object.mbt"],
    suites,
    GIT_COMPAT_AFFECTED_RULES,
  );
  assert.deepEqual(selected, suites);
});

test("bit-only modules select no git suites", () => {
  const selected = selectSuitesForChanges(
    ["modules/bitx_hub/src/issue.mbt", "modules/bitx_kv/src/store.mbt"],
    ["third_party/git/t/t0000-basic.sh"],
    GIT_COMPAT_AFFECTED_RULES,
  );
  assert.deepEqual(selected, []);
});
