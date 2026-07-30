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

test("rejects an unknown release bump argument", () => {
  const result = runScript(["major", "--since", "HEAD"]);

  assert.notEqual(result.status, 0);
  assert.match(result.stdout, /unknown argument `major`; expected `patch` or `minor`/);
});

test("patch leaves release metadata untouched when its diff is empty", () => {
  const result = runScript(["patch", "--since", "HEAD"]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(
    result.stdout,
    /no modules changed since HEAD — release metadata was not updated/,
  );
});

test("minor leaves release metadata untouched when its diff is empty", () => {
  const result = runScript(["minor", "--since", "HEAD"]);

  assert.equal(result.status, 0, result.stderr);
  assert.match(
    result.stdout,
    /no modules changed since HEAD — release metadata was not updated/,
  );
});

test("release preparation cannot publish from its dirty prepared worktree", () => {
  const result = runScript(["patch", "--apply", "--since", "HEAD"]);

  assert.notEqual(result.status, 0);
  assert.match(
    result.stdout,
    /prepares release metadata; commit and tag it before --apply/,
  );
});

test("release preparation updates only modules changed since its anchor", () => {
  const source = readFileSync(
    new URL("./publish-changed.mbtx", import.meta.url),
    "utf8",
  );

  assert.match(source, /"patch" => Patch/);
  assert.match(source, /"minor" => Minor/);
  assert.match(source, /prepare_release_versions\(root, modules, changed_dirs, kind\)/);
  assert.match(source, /if !changed_dirs\.contains\(m\.dir_basename\)/);
  assert.match(source, /if m\.dir_basename == "bit"/);
  assert.doesNotMatch(source, /workspace versions must match/);
  assert.doesNotMatch(source, /sub != "moon\.mod"/);
  assert.match(source, /"--grep=\^Release"/);
  assert.match(source, /"--skip=1"/);
  assert.doesNotMatch(source, /publishing the full workspace version/);
});
