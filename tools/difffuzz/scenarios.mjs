// Differential scenarios: the same random history on git and on bit.
//
// Each step is chosen from the *reference* (git) repository's current state
// (tracked files, branches, merge in progress, ...), then applied to both
// sides. Commands may legitimately fail (e.g. switching with conflicting
// local changes); what matters is that git and bit agree on success, and
// end in the same state.

import fs from "node:fs";
import path from "node:path";
import { crashRecoveryProblems, gitOut, restoreProblems, run } from "./lib.mjs";

const DIRS = ["", "a/", "a/b/", "c/", "c/d/e/", "sp ace/", "ué/"];
const NAMES = ["f.txt", "g.md", "h", "data.bin", "x-1.txt", ".hidden", "README"];
const BRANCHES = ["main", "f1", "f2", "topic/a", "b-3"];
const TAGS = ["v1", "v2", "rel/x"];

function randomContent(rng) {
  switch (rng.int(8)) {
    case 0:
      return Buffer.alloc(0);
    case 1:
      return rng.bytes(1 + rng.int(300)); // binary
    case 2:
      return Buffer.from(
        Array.from({ length: 1 + rng.int(6) }, (_, i) => `crlf ${i} ${rng.int(9)}\r\n`).join(""),
      );
    case 3:
      return rng.chance(0.5) ? rng.bytes(64 * 1024 + rng.int(64 * 1024)) : Buffer.from("x\n"); // large
    case 4:
      return Buffer.from(`no trailing newline ${rng.int(1000)}`);
    default: {
      // Mostly-shared text, so merges touch nearby lines.
      const lines = [];
      for (let i = 0; i < 6; i++) lines.push(rng.chance(0.3) ? `line ${i} ${rng.int(5)}` : `line ${i}`);
      return Buffer.from(lines.join("\n") + "\n");
    }
  }
}

function listTracked(pair, rel) {
  return (gitOut(pair.path("git", rel), ["ls-files"], pair.env) ?? "").split("\n").filter(Boolean);
}

function listWorkFiles(pair, rel) {
  const root = pair.path("git", rel);
  const out = [];
  const visit = (dir, r) => {
    for (const name of fs.readdirSync(dir)) {
      if (r === "" && name === ".git") continue;
      const abs = path.join(dir, name);
      const rr = r ? `${r}/${name}` : name;
      const st = fs.lstatSync(abs);
      if (st.isDirectory() && !st.isSymbolicLink()) visit(abs, rr);
      else out.push(rr);
    }
  };
  visit(root, "");
  return out;
}

function branches(pair, rel) {
  return (gitOut(pair.path("git", rel), ["for-each-ref", "--format=%(refname:short)", "refs/heads"], pair.env) ?? "")
    .split("\n")
    .filter(Boolean);
}

function inMerge(pair, rel) {
  const p = gitOut(pair.path("git", rel), ["rev-parse", "--git-path", "MERGE_HEAD"], pair.env);
  return p !== null && fs.existsSync(path.resolve(pair.path("git", rel), p.trim()));
}

function inSequencer(pair, rel) {
  for (const n of ["CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply"]) {
    const p = gitOut(pair.path("git", rel), ["rev-parse", "--git-path", n], pair.env);
    if (p !== null && fs.existsSync(path.resolve(pair.path("git", rel), p.trim()))) return n;
  }
  return null;
}

function hasCommits(pair, rel) {
  return gitOut(pair.path("git", rel), ["rev-parse", "-q", "--verify", "HEAD"], pair.env) !== null;
}

function hasParent(pair, rel) {
  return gitOut(pair.path("git", rel), ["rev-parse", "-q", "--verify", "HEAD~1"], pair.env) !== null;
}

function randomPath(rng) {
  return rng.pick(DIRS) + rng.pick(NAMES);
}

/** One random step in worktree `rel`. Returns an action the runner applies. */
export function coreStep(pair, rel) {
  const rng = pair.rng;
  if (inMerge(pair, rel)) {
    // Finish or abort the merge.
    if (rng.chance(0.4)) return { cmd: ["merge", "--abort"] };
    const tracked = listTracked(pair, rel);
    return {
      edit: [`resolve conflicts by overwriting ${tracked.length} file(s)`, (root) => {
        for (const f of tracked) {
          const abs = path.join(root, f);
          if (fs.existsSync(abs) && !fs.lstatSync(abs).isSymbolicLink()) {
            const t = fs.readFileSync(abs);
            if (t.includes("<<<<<<<")) fs.writeFileSync(abs, `resolved ${f}\n`);
          }
        }
      }],
      then: [["add", "-A"], ["commit", "-q", "--no-edit"]],
    };
  }
  const seq = inSequencer(pair, rel);
  if (seq) {
    return { cmd: seq.startsWith("rebase") ? ["rebase", "--abort"] : seq === "REVERT_HEAD" ? ["revert", "--abort"] : ["cherry-pick", "--abort"] };
  }
  const tracked = listTracked(pair, rel);
  const work = listWorkFiles(pair, rel);
  const brs = branches(pair, rel);
  const others = brs.filter((b) => b !== "");
  const committed = hasCommits(pair, rel);
  const roll = rng.int(100);

  if (roll < 22) {
    const p = rng.chance(0.6) && work.length ? rng.pick(work) : randomPath(rng);
    const data = randomContent(rng);
    return {
      edit: [`write ${p} (${data.length} bytes)`, (root) => {
        const abs = path.join(root, p);
        if (fs.existsSync(abs) && fs.lstatSync(abs).isDirectory()) return;
        fs.mkdirSync(path.dirname(abs), { recursive: true });
        if (fs.existsSync(abs) && fs.lstatSync(abs).isSymbolicLink()) fs.rmSync(abs);
        fs.writeFileSync(abs, data);
      }],
    };
  }
  if (roll < 27 && work.length) {
    const p = rng.pick(work);
    return { edit: [`delete ${p}`, (root) => fs.rmSync(path.join(root, p), { force: true, recursive: true })] };
  }
  if (roll < 30 && work.length) {
    const from = rng.pick(work);
    const to = randomPath(rng);
    return {
      edit: [`rename ${from} -> ${to}`, (root) => {
        const a = path.join(root, from);
        const b = path.join(root, to);
        if (!fs.existsSync(a) || fs.existsSync(b) || to.startsWith(from + "/")) return;
        fs.mkdirSync(path.dirname(b), { recursive: true });
        fs.renameSync(a, b);
      }],
    };
  }
  if (roll < 33 && work.length) {
    const p = rng.pick(work);
    return {
      edit: [`chmod toggle +x ${p}`, (root) => {
        const abs = path.join(root, p);
        if (!fs.existsSync(abs) || fs.lstatSync(abs).isSymbolicLink()) return;
        const m = fs.statSync(abs).mode;
        fs.chmodSync(abs, m & 0o111 ? 0o644 : 0o755);
      }],
    };
  }
  if (roll < 35) {
    const p = randomPath(rng);
    const target = rng.pick(["f.txt", "../a/f.txt", "missing", "a/b"]);
    return {
      edit: [`symlink ${p} -> ${target}`, (root) => {
        const abs = path.join(root, p);
        if (fs.existsSync(abs) || fs.lstatSync(path.dirname(abs), { throwIfNoEntry: false })?.isSymbolicLink()) return;
        fs.mkdirSync(path.dirname(abs), { recursive: true });
        try {
          fs.symlinkSync(target, abs);
        } catch {}
      }],
    };
  }
  if (roll < 47) {
    const v = rng.int(4);
    if (v === 0) return { cmd: ["add", "-A"] };
    if (v === 1) return { cmd: ["add", "."] };
    if (v === 2 && tracked.length) return { cmd: ["add", "-u"] };
    if (work.length) return { cmd: ["add", "--", rng.pick(work)] };
    return { cmd: ["add", "-A"] };
  }
  if (roll < 60) {
    const msg = `c${pair.clock}`;
    const v = rng.int(4);
    if (v === 0) return { cmd: ["commit", "-q", "-a", "-m", msg] };
    if (v === 1) return { cmd: ["commit", "-q", "--allow-empty", "-m", msg] };
    return { cmd: ["commit", "-q", "-m", msg] };
  }
  if (!committed) return { cmd: ["add", "-A"] };
  if (roll < 65) {
    const b = rng.pick(BRANCHES);
    const v = rng.int(3);
    if (v === 0) return { cmd: ["branch", b] };
    if (v === 1) return { cmd: ["checkout", "-q", "-b", b] };
    return { cmd: ["switch", "-q", "-c", b] };
  }
  if (roll < 72 && others.length) {
    const b = rng.pick(others);
    if (rng.chance(0.15)) return { cmd: ["checkout", "-q", "--detach", "HEAD"] };
    return { cmd: rng.chance(0.5) ? ["checkout", "-q", b] : ["switch", "-q", b] };
  }
  if (roll < 78 && others.length) {
    const b = rng.pick(others);
    return { cmd: rng.chance(0.5) ? ["merge", "-q", "--no-edit", b] : ["merge", "-q", "--no-ff", "--no-edit", b] };
  }
  if (roll < 82 && hasParent(pair, rel)) {
    return { cmd: ["reset", "-q", rng.pick(["--hard", "--soft", "--mixed"]), "HEAD~1"] };
  }
  if (roll < 85 && tracked.length) {
    const p = rng.pick(tracked);
    return { cmd: rng.chance(0.5) ? ["rm", "-q", "--", p] : ["rm", "-q", "--cached", "--", p] };
  }
  if (roll < 87 && tracked.length) {
    const p = rng.pick(tracked);
    return { cmd: ["mv", "--", p, randomPath(rng)] };
  }
  if (roll < 91) {
    const v = rng.int(3);
    if (v === 0) return { cmd: ["stash", "push", "-q"] };
    if (v === 1) return { cmd: ["stash", "pop", "-q"] };
    return { cmd: ["stash", "push", "-q", "-u"] };
  }
  if (roll < 93) {
    const t = rng.pick(TAGS);
    return { cmd: rng.chance(0.5) ? ["tag", t] : ["tag", "-a", t, "-m", `tag ${t}`] };
  }
  if (roll < 95 && tracked.length) {
    const p = rng.pick(tracked);
    return { cmd: rng.chance(0.5) ? ["checkout", "--", p] : ["restore", "--", p] };
  }
  if (roll < 97 && others.length) {
    const b = rng.pick(others);
    return { cmd: rng.chance(0.5) ? ["cherry-pick", b] : ["revert", "--no-edit", "HEAD"] };
  }
  if (roll < 98 && others.length > 1) {
    const b = rng.pick(others);
    return { cmd: ["branch", "-D", b] };
  }
  return { cmd: rng.chance(0.5) ? ["gc", "-q"] : ["repack", "-a", "-d", "-q"] };
}

/** Apply a step to both sides; return problems (empty when they agree). */
export function applyStep(pair, rel, step, worktrees) {
  const problems = [];
  const runCmd = (args) => {
    const r = pair.both(args, rel);
    if (r.crashed) return { crashed: true };
    const gOk = r.git.code === 0;
    const bOk = r.bit.code === 0;
    if (gOk !== bOk) {
      problems.push(
        `exit status differs for \`${args.join(" ")}\` in ${rel}: git=${r.git.code} bit=${r.bit.code}\n` +
          `    git stderr: ${r.git.stderr.trim().slice(0, 400)}\n` +
          `    bit stderr: ${r.bit.stderr.trim().slice(0, 400)}`,
      );
    }
    return { crashed: false };
  };
  if (step.edit) pair.edit(step.edit[0], step.edit[1], rel);
  const cmds = step.cmd ? [step.cmd] : (step.then ?? []);
  for (const c of cmds) {
    if (runCmd(c).crashed) return { problems, crashed: true };
  }
  problems.push(...pair.check(worktrees));
  return { problems, crashed: false };
}

// ------------------------------------------------------------ scenarios --

function initPair(pair) {
  for (const side of ["git", "bit"]) fs.mkdirSync(pair.path(side, "repo"), { recursive: true });
  const r = pair.both(["init", "-q"], "repo");
  if (r.git.code !== 0 || r.bit.code !== 0) throw new Error(`init failed: ${r.bit.stderr}`);
}

function finish(pair, problems) {
  if (problems.length) return problems;
  return restoreProblems({
    repo: pair.path("bit", "repo"),
    bit: pair.bit,
    env: pair.env,
    workdir: pair.root,
  });
}

export function runCore(pair, steps) {
  initPair(pair);
  for (let i = 0; i < steps; i++) {
    const step = coreStep(pair, "repo");
    const { problems, crashed } = applyStep(pair, "repo", step, ["repo"]);
    if (crashed) return { step: i, problems: crashRecoveryProblems(pair.path("bit", "repo"), pair.env), crashed };
    if (problems.length) return { step: i, problems };
  }
  return { step: steps, problems: finish(pair, []) };
}

export function runWorktree(pair, steps) {
  initPair(pair);
  const worktrees = ["repo"];
  for (let i = 0; i < steps; i++) {
    const rng = pair.rng;
    let step;
    let rel = rng.pick(worktrees);
    const roll = rng.int(100);
    if (roll < 12 && hasCommits(pair, "repo") && worktrees.length < 4) {
      const n = `wt${i}`;
      const b = `w${i}`;
      step = { cmd: ["worktree", "add", "-q", "-b", b, `../${n}`] };
      rel = "repo";
      const res = applyStep(pair, rel, step, worktrees);
      if (fs.existsSync(pair.path("git", n))) worktrees.push(n);
      if (res.crashed) return { step: i, problems: crashRecoveryProblems(pair.path("bit", "repo"), pair.env), crashed: true };
      if (res.problems.length) return { step: i, problems: res.problems };
      const again = pair.check(worktrees);
      if (again.length) return { step: i, problems: again };
      continue;
    }
    if (roll < 16 && worktrees.length > 1) {
      const n = rng.pick(worktrees.slice(1));
      step = { cmd: ["worktree", "remove", rng.chance(0.5) ? "--force" : "", `../${n}`].filter(Boolean) };
      const res = applyStep(pair, "repo", step, ["repo"]);
      if (!fs.existsSync(pair.path("git", n))) worktrees.splice(worktrees.indexOf(n), 1);
      if (res.crashed) return { step: i, problems: crashRecoveryProblems(pair.path("bit", "repo"), pair.env), crashed: true };
      if (res.problems.length) return { step: i, problems: res.problems };
      continue;
    }
    if (roll < 18) {
      step = { cmd: ["worktree", "prune"] };
      rel = "repo";
    } else {
      step = coreStep(pair, rel);
    }
    const { problems, crashed } = applyStep(pair, rel, step, worktrees);
    if (crashed) return { step: i, problems: crashRecoveryProblems(pair.path("bit", "repo"), pair.env), crashed };
    if (problems.length) return { step: i, problems };
    // `worktree list` must agree too (paths relative to each side).
    const lists = ["git", "bit"].map((side) =>
      (gitOut(pair.path(side, "repo"), ["worktree", "list", "--porcelain"], pair.env) ?? "(error)")
        .split(pair.sides[side])
        .join("<root>"),
    );
    if (lists[0] !== lists[1]) return { step: i, problems: [`worktree list differs:\n  git: ${lists[0]}\n  bit: ${lists[1]}`] };
  }
  return { step: steps, problems: finish(pair, []) };
}

export function runSparse(pair, steps) {
  initPair(pair);
  const cones = ["a", "a/b", "c", "c/d", "sp ace"];
  for (let i = 0; i < steps; i++) {
    const rng = pair.rng;
    let step;
    const roll = rng.int(100);
    if (roll < 15 && hasCommits(pair, "repo")) {
      const v = rng.int(4);
      const picks = Array.from({ length: 1 + rng.int(2) }, () => rng.pick(cones));
      if (v === 0) step = { cmd: ["sparse-checkout", "set", "--cone", ...picks] };
      else if (v === 1) step = { cmd: ["sparse-checkout", "add", ...picks] };
      else if (v === 2) step = { cmd: ["sparse-checkout", "disable"] };
      else step = { cmd: ["sparse-checkout", "reapply"] };
    } else {
      step = coreStep(pair, "repo");
    }
    const { problems, crashed } = applyStep(pair, "repo", step, ["repo"]);
    if (crashed) return { step: i, problems: crashRecoveryProblems(pair.path("bit", "repo"), pair.env), crashed };
    if (problems.length) return { step: i, problems };
  }
  return { step: steps, problems: finish(pair, []) };
}

export { run };
