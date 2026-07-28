import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import test from "node:test";

const runScript = (args) => spawnSync(
  "moon",
  ["run", "--target", "native", "tools/publish-changed.mbtx", "--", ...args],
  { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
);

test("publish-changed never publishes without the --apply gate", () => {
  const source = readFileSync(
    new URL("./publish-changed.mbtx", import.meta.url),
    "utf8",
  );

  assert.match(source, /if !apply \{/);
  assert.match(source, /dry run — pass --apply/);
  assert.match(source, /refusing to publish from a dirty worktree/);
});

test("reports no changes when compared against HEAD itself", () => {
  const result = runScript(["--since", "HEAD"]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /no modules changed since HEAD — nothing to publish/);
});
