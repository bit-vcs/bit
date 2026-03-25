import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const repoRoot = new URL("../", import.meta.url);
const npmPackageJsonUrl = new URL("../npm/package.json", import.meta.url);

const readNpmVersion = async () => {
  const source = await readFile(npmPackageJsonUrl, "utf8");
  return JSON.parse(source).version;
};

test("npm CLI wrapper runs under type module", async () => {
  const version = await readNpmVersion();
  const { stdout, stderr } = await execFileAsync(
    process.execPath,
    ["npm/bin/bit.mjs", "--version"],
    { cwd: repoRoot },
  );

  assert.match(stdout, new RegExp(`git version 2\\.47\\.0 \\(bit v${version.replaceAll(".", "\\.")}\\)`));
  assert.equal(stderr, "");
});

test("npm bit.js wrapper can be imported from ESM without crashing", async () => {
  const { stdout, stderr } = await execFileAsync(
    process.execPath,
    ["--input-type=module", "-e", "import('./npm/bit.js')"],
    { cwd: repoRoot },
  );

  assert.match(stdout, /usage: bit \[-v \| --version]/);
  assert.equal(stderr, "");
});
