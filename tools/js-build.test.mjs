import assert from "node:assert/strict";
import test from "node:test";

import * as builtBitGit from "./bit-git.mjs";
import { trackModuleUsage, assertAllExportedFunctionsUsed } from "./track-module-usage.mjs";
import { verifyBitGitModule } from "./verify-libgit2-js.mjs";
import { verifyRelayModule } from "./verify-libgit2-relay.mjs";
import { verifyTreeshakeBundles } from "./verify-lib-js-treeshake.mjs";

test("built JS lib wrapper exercises the full exported API surface", async () => {
  const { proxy, used } = trackModuleUsage(builtBitGit);
  const localResult = await verifyBitGitModule(proxy);
  const relayResult = await verifyRelayModule(proxy);

  assert.equal(typeof localResult.memoryResult.commitId, "string");
  assert.equal(localResult.memoryResult.commitId.length, 40);
  assert.equal(relayResult, "ok");
  assertAllExportedFunctionsUsed(builtBitGit, used);
});

test("tree-shaken bundles stay within guardrails", async () => {
  const result = await verifyTreeshakeBundles();
  assert.ok(result.minimal.rawBytes < result.gitOps.rawBytes);
  assert.ok(result.minimal.gzipBytes < result.gitOps.gzipBytes);
});
