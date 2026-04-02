#!/usr/bin/env node

import { cpSync, chmodSync, existsSync, mkdirSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import {
  GIT_COMPAT_TASK_ID,
  normalizeSelectedScripts,
  readAllowlistEntries,
  resolveShimRefreshAction,
  toGitCompatSuite,
} from "./flaker-git-compat-lib.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const CI_SHIM_COMMANDS = [
  "init", "add", "diff", "diff-files", "diff-index", "ls-files", "tag",
  "branch", "checkout", "switch", "commit", "log", "show", "reflog",
  "reset", "update-ref", "update-index", "status", "merge", "rebase",
  "clone", "push", "fetch", "pull", "mv", "notes", "stash", "rm",
  "submodule", "worktree", "config", "show-ref", "for-each-ref",
  "rev-parse", "symbolic-ref", "cherry-pick", "remote", "cat-file",
  "hash-object", "ls-tree", "write-tree", "commit-tree", "receive-pack",
  "upload-pack", "pack-objects", "index-pack", "format-patch", "describe",
  "gc", "clean", "sparse-checkout", "restore", "blame", "grep", "shell",
  "rev-list", "bisect", "diff-tree", "read-tree", "fsck", "am", "apply",
  "bundle", "cherry", "revert", "prune", "pack-refs", "mktree",
  "shortlog", "verify-pack", "unpack-objects", "maintenance",
  "range-diff", "show-branch", "repack", "multi-pack-index",
  "pack-redundant", "send-pack", "request-pull", "merge-base", "var",
  "stripspace", "ls-remote", "fmt-merge-msg", "patch-id", "count-objects",
  "name-rev", "update-server-info", "check-ref-format", "mktag",
  "interpret-trailers", "column", "merge-tree", "merge-file", "fast-import",
  "fast-export", "verify-tag", "fetch-pack", "difftool", "rerere",
  "mailinfo", "archive", "check-attr", "check-ignore", "show-index",
  "get-tar-commit-id", "verify-commit", "annotate",
].join(" ");

function fail(message, exitCode = 1) {
  console.error(message);
  process.exit(exitCode);
}

function run(command, args, opts = {}) {
  return spawnSync(command, args, {
    cwd: opts.cwd ?? root,
    env: { ...process.env, ...(opts.env ?? {}) },
    encoding: "utf8",
    timeout: opts.timeout,
  });
}

function ensureOk(result, label) {
  if (result.error) {
    throw result.error;
  }
  if (typeof result.status === "number" && result.status !== 0) {
    const stderr = result.stderr?.trim();
    throw new Error(`${label} failed${stderr ? `: ${stderr}` : ""}`);
  }
}

function maybeGettextEnv() {
  const brew = run("brew", ["--prefix", "gettext"]);
  if (brew.error || brew.status !== 0) {
    return {};
  }
  const prefix = brew.stdout.trim();
  if (!prefix) return {};
  return {
    CPATH: `${prefix}/include`,
    LDFLAGS: `-L${prefix}/lib`,
    LIBRARY_PATH: `${prefix}/lib`,
  };
}

function ensurePrepared() {
  const patch = run("bash", ["tools/apply-git-test-patches.sh"]);
  ensureOk(patch, "apply-git-test-patches");

  const shimMoon = join(root, "tools/git-shim/moon");
  const builtBit = join(
    root,
    "_build/native/release/build/cmd/bit/bit.exe",
  );
  const action = resolveShimRefreshAction({
    shimExists: existsSync(shimMoon),
    builtBitExists: existsSync(builtBit),
    shimMtimeMs: existsSync(shimMoon) ? statSync(shimMoon).mtimeMs : null,
    builtBitMtimeMs: existsSync(builtBit) ? statSync(builtBit).mtimeMs : null,
  });

  if (action === "build") {
    const build = run("moon", ["build", "--target", "native", "--release"]);
    ensureOk(build, "moon build");
  }

  if (!existsSync(builtBit)) {
    throw new Error(`bit binary not found after prepare step: ${builtBit}`);
  }

  if (action !== "keep") {
    mkdirSync(dirname(shimMoon), { recursive: true });
    cpSync(builtBit, shimMoon);
    chmodSync(shimMoon, 0o755);
  }
}

function resolveRealGit() {
  const bundled = join(root, "third_party/git/git");
  if (existsSync(bundled)) {
    const whichGit = run("/usr/bin/which", ["git"]);
    const fallbackRealGit =
      whichGit.status === 0 && whichGit.stdout.trim() !== bundled
        ? whichGit.stdout.trim()
        : "";
    return {
      realGit: bundled,
      execPath: join(root, "third_party/git"),
      fallbackRealGit,
    };
  }

  const whichGit = run("/usr/bin/which", ["git"]);
  ensureOk(whichGit, "which git");
  const realGit = whichGit.stdout.trim();
  const execPathResult = run(realGit, ["--exec-path"]);
  ensureOk(execPathResult, "git --exec-path");
  return {
    realGit,
    execPath: execPathResult.stdout.trim(),
    fallbackRealGit: "",
  };
}

function buildCompatEnv() {
  ensurePrepared();
  const { realGit, execPath, fallbackRealGit } = resolveRealGit();
  writeFileSync(join(root, "tools/git-shim/real-git-path"), `${realGit}\n`);
  return {
    ...maybeGettextEnv(),
    SHIM_REAL_GIT: realGit,
    SHIM_REAL_GIT_FALLBACK: fallbackRealGit,
    SHIM_EXEC_PATH: execPath,
    SHIM_MOON: join(root, "tools/git-shim/moon"),
    SHIM_CMDS: CI_SHIM_COMMANDS,
    SHIM_STRICT: "1",
    GIT_TEST_INSTALLED: join(root, "tools/git-shim/bin"),
    GIT_TEST_EXEC_PATH: execPath,
    GIT_TEST_DEFAULT_HASH: "sha1",
  };
}

function summarizeFailure(scriptName, stdout, stderr, exitCode) {
  const lines = `${stdout}\n${stderr}`
    .split(/\r?\n/)
    .map((line) => line.trimEnd())
    .filter(Boolean);
  const tail = lines.slice(-20).join("\n");
  return tail || `${scriptName} failed with exit code ${exitCode}`;
}

async function parseInput() {
  let raw = "";
  for await (const chunk of process.stdin) {
    raw += chunk;
  }
  return raw ? JSON.parse(raw) : { tests: [], opts: {} };
}

function executeSelectedTests(selectedScripts, timeout) {
  if (selectedScripts.length === 0) {
    return {
      exitCode: 0,
      results: [],
      durationMs: 0,
      stdout: "",
      stderr: "",
    };
  }

  const env = buildCompatEnv();
  const results = [];
  const stdoutChunks = [];
  const stderrChunks = [];
  let hasFailure = false;
  const startedAt = Date.now();

  for (const scriptName of selectedScripts) {
    const suite = toGitCompatSuite(scriptName);
    const testName = basename(scriptName);
    const testStartedAt = Date.now();
    const command = run(
      "bash",
      ["tools/run-git-test.sh", `T=${scriptName}`],
      { env, timeout },
    );
    const durationMs = Date.now() - testStartedAt;
    const stdout = command.stdout ?? "";
    const stderr = command.stderr ?? "";
    const exitCode = command.status ?? 1;

    stdoutChunks.push(`## ${scriptName}\n${stdout}`);
    if (stderr.trim()) {
      stderrChunks.push(`## ${scriptName}\n${stderr}`);
    }

    if (exitCode !== 0) {
      hasFailure = true;
    }

    results.push({
      suite,
      testName,
      taskId: GIT_COMPAT_TASK_ID,
      status: exitCode === 0 ? "passed" : "failed",
      durationMs,
      retryCount: 0,
      ...(exitCode === 0
        ? {}
        : {
            errorMessage: summarizeFailure(scriptName, stdout, stderr, exitCode),
          }),
    });
  }

  return {
    exitCode: hasFailure ? 1 : 0,
    results,
    durationMs: Date.now() - startedAt,
    stdout: stdoutChunks.join("\n"),
    stderr: stderrChunks.join("\n"),
  };
}

try {
  const payload = await parseInput();
  const allowlistEntries = readAllowlistEntries();
  const selectedScripts = normalizeSelectedScripts(
    payload.tests ?? [],
    allowlistEntries,
  );
  const executeResult = executeSelectedTests(
    selectedScripts,
    payload.opts?.timeout,
  );
  process.stdout.write(JSON.stringify(executeResult, null, 2));
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}
