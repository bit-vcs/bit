import assert from "node:assert/strict";
import test from "node:test";

import * as npmBitGit from "../npm/lib.js";
import { trackModuleUsage, assertAllExportedFunctionsUsed } from "./track-module-usage.mjs";
import { verifyBitGitModule } from "./verify-libgit2-js.mjs";
import { verifyRelayModule } from "./verify-libgit2-relay.mjs";

test("npm wrapper exercises the full exported API surface", async () => {
  const { proxy, used } = trackModuleUsage(npmBitGit);
  const localResult = await verifyBitGitModule(proxy);
  const relayResult = await verifyRelayModule(proxy);

  assert.equal(localResult.memoryResult.commitId.length, 40);
  assert.equal(relayResult, "ok");
  assertAllExportedFunctionsUsed(npmBitGit, used);
});
