import assert from "node:assert/strict";
import test from "node:test";

import {
  parseWorkspaceModules,
  parseModuleGraph,
  reverseClosure,
  moduleForPath,
  selectAffected,
} from "./select-affected-tests.mjs";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");

test("workspace modules parse from moon.work", () => {
  const members = parseWorkspaceModules(ROOT);
  assert.ok(members.includes("modules/bit"));
  assert.ok(members.includes("modules/bit_lib"));
  assert.ok(members.length > 30);
});

test("module graph has reverse-dependency closure to mizchi/bit", () => {
  const members = parseWorkspaceModules(ROOT);
  const graph = parseModuleGraph(ROOT, members);
  const affected = reverseClosure(graph, ["mizchi/bit_diff_core"]);
  // bit_diff imports bit_diff_core; the CLI imports bit_diff.
  assert.ok(affected.has("mizchi/bit_diff_core"));
  assert.ok(affected.has("mizchi/bit_diff"));
  assert.ok(affected.has("mizchi/bit"));
});

test("moduleForPath picks the longest member match", () => {
  const members = ["modules/bit", "modules/bit_lib"];
  assert.equal(
    moduleForPath(members, "modules/bit_lib/src/merge.mbt"),
    "modules/bit_lib",
  );
  assert.equal(
    moduleForPath(members, "modules/bit/cmd/bit/merge.mbt"),
    "modules/bit",
  );
});

test("docs-only changes select nothing", () => {
  const result = selectAffected(ROOT, ["docs/introduce-bit.md", "README.md"]);
  assert.equal(result.full, false);
  assert.deepEqual(result.moon_targets, []);
  assert.deepEqual(result.git_tests, []);
});

test("bitx_hub changes run moon tests but no git-compat suites", () => {
  const result = selectAffected(ROOT, ["modules/bitx_hub/src/issue.mbt"]);
  assert.equal(result.full, false);
  assert.ok(result.moon_targets.includes("mizchi/bitx_hub"));
  assert.equal(result.git_tests.length, 0);
  // The CLI depends on bitx_hub, so cmd shards must still run.
  assert.equal(result.cmd_bit, true);
});

test("bit_diff changes select the diff suites, not the world", () => {
  const result = selectAffected(ROOT, ["modules/bit_diff/src/myers.mbt"]);
  assert.equal(result.full, false);
  assert.ok(result.git_tests.length > 0);
  assert.ok(
    result.git_tests.every(
      (t) =>
        /\/t40[0-9]+/.test(t) || t.includes("t6427-diff3-conflict-markers"),
    ),
    `unexpected suites: ${result.git_tests.slice(0, 5)}`,
  );
});

test("workflow changes force a full run", () => {
  const result = selectAffected(ROOT, [".github/workflows/ci.yml"]);
  assert.equal(result.full, true);
});

test("unmapped module files force a full run (safety net)", () => {
  const result = selectAffected(ROOT, [
    "modules/bit_lib/src/some_brand_new_area.mbt",
  ]);
  assert.equal(result.full, true);
  assert.ok(result.reasons.some((r) => r.startsWith("unmapped:")));
});
