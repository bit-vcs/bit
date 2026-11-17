// Differential fuzzing harness: bit vs real git.
//
// Every scenario drives two repositories with the same random sequence of
// filesystem edits and commands -- one with real git (the reference), one
// with bit (`--no-git-fallback`, so nothing is delegated) -- and after each
// step compares their state *as read by real git*: HEAD, every ref (object
// ids must match exactly; dates and identities are fixed), the index
// (including skip-worktree), every worktree file (content + mode + symlink
// target), `status`, and in-progress merge state. The bit repository must
// also pass `git fsck --strict` after every step.
//
// Runs are deterministic per seed, so a failure is reproduced by re-running
// the printed command line.

import { spawnSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

// ---------------------------------------------------------------- PRNG ----

export function makeRng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int: (n) => Math.floor(next() * n),
    pick: (arr) => arr[Math.floor(next() * arr.length)],
    chance: (p) => next() < p,
    bytes: (n) => {
      const b = Buffer.alloc(n);
      for (let i = 0; i < n; i++) b[i] = Math.floor(next() * 256);
      return b;
    },
  };
}

// ------------------------------------------------------------- process ----

/** A clean environment: no inherited GIT_* (this container pre-sets
 * GIT_CONFIG_COUNT/KEY/VALUE, which would make bit delegate to git). */
export function makeEnv(home) {
  const env = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (!k.startsWith("GIT_")) env[k] = v;
  }
  Object.assign(env, {
    HOME: home,
    XDG_CONFIG_HOME: path.join(home, ".config"),
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_CONFIG_GLOBAL: path.join(home, ".gitconfig"),
    GIT_EDITOR: "true",
    GIT_TERMINAL_PROMPT: "0",
    GIT_AUTHOR_NAME: "Fuzz",
    GIT_AUTHOR_EMAIL: "fuzz@example.com",
    GIT_COMMITTER_NAME: "Fuzz",
    GIT_COMMITTER_EMAIL: "fuzz@example.com",
    LC_ALL: "C",
    TZ: "UTC",
  });
  fs.mkdirSync(home, { recursive: true });
  fs.writeFileSync(
    env.GIT_CONFIG_GLOBAL,
    [
      "[init]",
      "\tdefaultBranch = main",
      "[protocol \"file\"]",
      "\tallow = always",
      "[advice]",
      "\tdetachedHead = false",
      "[core]",
      "\tautocrlf = false",
      "",
    ].join("\n"),
  );
  return env;
}

export function run(cmd, args, { cwd, env, timeoutMs = 120_000, input } = {}) {
  const r = spawnSync(cmd, args, {
    cwd,
    env,
    input,
    encoding: "buffer",
    timeout: timeoutMs,
    maxBuffer: 256 * 1024 * 1024,
  });
  return {
    code: r.error?.code === "ETIMEDOUT" ? "timeout" : (r.status ?? `signal:${r.signal}`),
    stdout: r.stdout ? r.stdout.toString("utf8") : "",
    stderr: r.stderr ? r.stderr.toString("utf8") : (r.error ? String(r.error) : ""),
  };
}

/** Real git, for setup and for reading state. */
export function git(cwd, args, env, opts = {}) {
  return run("git", args, { cwd, env, ...opts });
}

export function gitOut(cwd, args, env) {
  const r = git(cwd, args, env);
  return r.code === 0 ? r.stdout : null;
}

// ------------------------------------------------------------ snapshot ----

function walkWorktree(root) {
  const out = [];
  const visit = (dir, rel) => {
    let names;
    try {
      names = fs.readdirSync(dir).sort();
    } catch {
      return;
    }
    for (const name of names) {
      if (rel === "" && name === ".git") continue;
      const abs = path.join(dir, name);
      const r = rel ? `${rel}/${name}` : name;
      const st = fs.lstatSync(abs);
      if (st.isSymbolicLink()) {
        out.push(`link ${fs.readlinkSync(abs)} ${r}`);
      } else if (st.isDirectory()) {
        // A nested repository (e.g. a submodule) is opaque here.
        if (fs.existsSync(path.join(abs, ".git"))) {
          out.push(`repo ${r}`);
          continue;
        }
        visit(abs, r);
      } else {
        const exec = (st.mode & 0o111) !== 0 ? "x" : "-";
        const sha = crypto.createHash("sha1").update(fs.readFileSync(abs)).digest("hex");
        out.push(`file ${exec} ${sha} ${r}`);
      }
    }
  };
  visit(root, "");
  return out;
}

function readGitPathFile(worktree, env, name) {
  const p = gitOut(worktree, ["rev-parse", "--git-path", name], env);
  if (p === null) return null;
  const abs = path.resolve(worktree, p.trim());
  return fs.existsSync(abs) ? fs.readFileSync(abs, "utf8").trim() : null;
}

// `git stash` moves an untracked file in its way to `<path>.stash.XXXXXX`
// with a random suffix; compare those names without it.
const STASH_TEMP_NAME = /\.stash\.[A-Za-z0-9]{6}(?=["\s]|$)/gm;
const maskStashTempNames = (text) => text.replace(STASH_TEMP_NAME, ".stash.XXXXXX");

/** State of one worktree, read with real git. */
export function snapshot(worktree, env) {
  const head =
    gitOut(worktree, ["symbolic-ref", "-q", "HEAD"], env)?.trim() ??
    gitOut(worktree, ["rev-parse", "-q", "--verify", "HEAD"], env)?.trim() ??
    "(unborn)";
  const headId = gitOut(worktree, ["rev-parse", "-q", "--verify", "HEAD"], env)?.trim() ?? "-";
  return {
    head: `${head} ${headId}`,
    refs: gitOut(worktree, ["for-each-ref", "--format=%(refname) %(objectname)"], env) ?? "(error)",
    index: gitOut(worktree, ["ls-files", "--stage"], env) ?? "(error)",
    indexFlags: gitOut(worktree, ["ls-files", "-v"], env) ?? "(error)",
    status: maskStashTempNames(
      gitOut(worktree, ["status", "--porcelain=v1", "-uall", "--ignored=no"], env) ?? "(error)",
    ),
    merge: ["MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD"]
      .map((n) => `${n}=${readGitPathFile(worktree, env, n) ?? "-"}`)
      .join(" "),
    files: maskStashTempNames(walkWorktree(worktree).join("\n")),
  };
}

export function diffSnapshots(a, b) {
  const diffs = [];
  for (const key of Object.keys(a)) {
    if (a[key] === b[key]) continue;
    const la = a[key].split("\n");
    const lb = b[key].split("\n");
    const sa = new Set(la);
    const sb = new Set(lb);
    const onlyA = la.filter((l) => !sb.has(l)).slice(0, 12);
    const onlyB = lb.filter((l) => !sa.has(l)).slice(0, 12);
    diffs.push(
      `  [${key}]\n` +
        onlyA.map((l) => `    git: ${l}`).join("\n") +
        (onlyA.length ? "\n" : "") +
        onlyB.map((l) => `    bit: ${l}`).join("\n"),
    );
  }
  return diffs;
}

/** `git fsck --strict` on the bit repository; null when clean. */
export function fsckProblem(repo, env) {
  const r = git(repo, ["fsck", "--strict", "--no-progress", "--no-dangling"], env);
  if (r.code === 0) return null;
  return `git fsck --strict failed (exit ${r.code}):\n${(r.stderr + r.stdout).trim().slice(0, 2000)}`;
}

// ------------------------------------------------------------- harness ----

/**
 * A pair of repositories driven in lockstep. `cwd` names are relative
 * to each side's root, so `pair.both(["worktree", "add", ...], "repo")`
 * runs in `<root>/git/repo` and `<root>/bit/repo`.
 */
export class Pair {
  constructor({ root, bit, env, crash, rng, log }) {
    this.root = root;
    this.bit = bit;
    this.env = env;
    this.crash = crash;
    this.rng = rng;
    this.log = log;
    this.clock = 1_700_000_000;
    this.sides = { git: path.join(root, "git"), bit: path.join(root, "bit") };
    for (const d of Object.values(this.sides)) fs.mkdirSync(d, { recursive: true });
  }

  path(side, rel) {
    return path.join(this.sides[side], rel);
  }

  tick() {
    this.clock += 60;
    const date = `${this.clock} +0000`;
    return { ...this.env, GIT_AUTHOR_DATE: date, GIT_COMMITTER_DATE: date };
  }

  /** Run the same command on both sides. Returns `{ git, bit, crashed }`. */
  both(args, rel) {
    const env = this.tick();
    const g = run("git", ["-C", this.path("git", rel), ...args], { env });
    let crashed = false;
    let b;
    if (this.crash > 0 && this.rng.chance(this.crash)) {
      // Kill bit partway through: the repository must stay recoverable.
      const ms = 1 + this.rng.int(40);
      b = run(this.bit, ["--no-git-fallback", "-C", this.path("bit", rel), ...args], {
        env: { ...env, PWD: this.path("bit", rel) },
        timeoutMs: ms,
      });
      crashed = b.code === "timeout";
    } else {
      b = run(this.bit, ["--no-git-fallback", "-C", this.path("bit", rel), ...args], {
        env: { ...env, PWD: this.path("bit", rel) },
      });
    }
    this.log.push(`$ git ${args.join(" ")}   # in ${rel}  git=${g.code} bit=${b.code}${crashed ? " (killed)" : ""}`);
    return { git: g, bit: b, crashed };
  }

  /** Apply a filesystem edit to worktree `rel` on both sides. */
  edit(desc, fn, rel) {
    this.log.push(`# ${desc}   # in ${rel}`);
    // Both trees are identical, so an edit that cannot be applied (e.g. a
    // write through a dangling symlinked directory) fails on both sides.
    for (const side of ["git", "bit"]) {
      try {
        fn(this.path(side, rel));
      } catch {}
    }
  }

  /** Compare every listed worktree and fsck the bit side. Returns problems. */
  check(worktrees) {
    const problems = [];
    for (const rel of worktrees) {
      const a = snapshot(this.path("git", rel), this.env);
      const b = snapshot(this.path("bit", rel), this.env);
      const d = diffSnapshots(a, b);
      if (d.length) problems.push(`state differs in ${rel}:\n${d.join("\n")}`);
    }
    const f = fsckProblem(this.path("bit", worktrees[0]), this.env);
    if (f) problems.push(f);
    return problems;
  }
}

/** Remove stale lock files a killed process leaves behind (what a user
 * does after a crash); returns the removed paths. */
export function removeStaleLocks(gitDir) {
  const removed = [];
  const visit = (dir) => {
    for (const name of fs.readdirSync(dir)) {
      const abs = path.join(dir, name);
      const st = fs.lstatSync(abs);
      if (st.isDirectory()) {
        if (name !== "objects") visit(abs);
      } else if (name.endsWith(".lock")) {
        fs.rmSync(abs);
        removed.push(path.relative(gitDir, abs));
      }
    }
  };
  if (fs.existsSync(gitDir)) visit(gitDir);
  return removed;
}

/** After a crash: the repository must be readable and consistent once
 * stale locks are gone. Returns problems. */
export function crashRecoveryProblems(repo, env) {
  const problems = [];
  const removed = removeStaleLocks(path.join(repo, ".git"));
  const f = fsckProblem(repo, env);
  if (f) problems.push(`after crash${removed.length ? ` (removed ${removed.join(", ")})` : ""}: ${f}`);
  for (const args of [["status", "--porcelain"], ["for-each-ref"], ["ls-files", "--stage"]]) {
    const r = git(repo, args, env);
    if (r.code !== 0) problems.push(`after crash: git ${args.join(" ")} failed: ${r.stderr.trim()}`);
  }
  const head = git(repo, ["rev-parse", "-q", "--verify", "HEAD^{commit}"], env);
  const unborn = git(repo, ["symbolic-ref", "-q", "HEAD"], env).code === 0 &&
    git(repo, ["rev-parse", "-q", "--verify", "HEAD"], env).code !== 0;
  if (head.code !== 0 && !unborn) problems.push("after crash: HEAD does not resolve to a commit");
  return problems;
}

/** Every commit in `repo`, checked out by bit from a fresh bit clone, must
 * reproduce exactly the tree git records for it. Returns problems. */
export function restoreProblems({ repo, bit, env, workdir, maxCommits = 25 }) {
  const problems = [];
  const commits = (gitOut(repo, ["rev-list", "--all", "--topo-order"], env) ?? "")
    .split("\n")
    .filter(Boolean)
    .slice(0, maxCommits);
  if (commits.length === 0) return problems;
  const clone = path.join(workdir, "restore");
  fs.rmSync(clone, { recursive: true, force: true });
  const c = run(bit, ["--no-git-fallback", "clone", "-q", repo, clone], {
    env: { ...env, PWD: workdir },
    cwd: workdir,
  });
  if (c.code !== 0) return [`restore: bit clone failed: ${c.stderr.trim()}`];
  for (const id of commits) {
    const co = run(bit, ["--no-git-fallback", "-C", clone, "checkout", "-q", "-f", "--detach", id], {
      env: { ...env, PWD: clone },
    });
    if (co.code !== 0) {
      problems.push(`restore: bit checkout ${id} failed: ${co.stderr.trim()}`);
      continue;
    }
    const expected = (gitOut(repo, ["-c", "core.quotePath=false", "ls-tree", "-r", id], env) ?? "")
      .split("\n")
      .filter(Boolean)
      .filter((l) => !l.startsWith("160000"))
      .map((l) => {
        const [meta, p] = l.split("\t");
        const [mode, , sha] = meta.split(" ");
        return `${mode} ${sha} ${p}`;
      })
      .sort();
    const actual = [];
    for (const entry of walkWorktree(clone)) {
      const parts = entry.split(" ");
      if (parts[0] === "file") {
        const p = parts.slice(3).join(" ");
        const data = fs.readFileSync(path.join(clone, p));
        const blob = crypto
          .createHash("sha1")
          .update(Buffer.concat([Buffer.from(`blob ${data.length}\0`), data]))
          .digest("hex");
        actual.push(`${parts[1] === "x" ? "100755" : "100644"} ${blob} ${p}`);
      } else if (parts[0] === "link") {
        const p = parts.slice(2).join(" ");
        const target = Buffer.from(parts[1]);
        const blob = crypto
          .createHash("sha1")
          .update(Buffer.concat([Buffer.from(`blob ${target.length}\0`), target]))
          .digest("hex");
        actual.push(`120000 ${blob} ${p}`);
      }
    }
    actual.sort();
    const e = expected.join("\n");
    const a = actual.join("\n");
    if (e !== a) {
      const se = new Set(expected);
      const sa = new Set(actual);
      problems.push(
        `restore: checkout of ${id} does not match its tree\n` +
          expected.filter((l) => !sa.has(l)).slice(0, 8).map((l) => `    tree: ${l}`).join("\n") +
          "\n" +
          actual.filter((l) => !se.has(l)).slice(0, 8).map((l) => `    disk: ${l}`).join("\n"),
      );
      break;
    }
  }
  return problems;
}
