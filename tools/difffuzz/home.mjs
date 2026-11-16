// `bit home` scenario: model-based. There is no git equivalent to diff
// against, so random histories (upstream pushes, local commits, dirty
// edits, manifest changes, worktrees) are interleaved with `bit home sync`
// and every sync is checked against invariants:
//
// - sync never creates merge commits and never loses local commits
//   (the old HEAD stays an ancestor of the new one);
// - a repository with tracked local changes is left untouched (HEAD and
//   file contents);
// - a clean repository whose history has not diverged ends exactly at the
//   upstream tip; a diverged one is left unchanged and makes sync fail;
// - a `subdir` entry checks out exactly the cone of that directory, and an
//   entry without one checks out the full tree;
// - every repository passes `git fsck --strict`.

import fs from "node:fs";
import path from "node:path";
import { fsckProblem, git, gitOut, run } from "./lib.mjs";

const UP_FILES = ["README", "apps/web/a.txt", "apps/web/sub/b.txt", "apps/api/c.txt", "apps/top.txt", "libs/x/x.txt"];
const SUBDIRS = [null, "apps/web", "apps/api", "libs"];

function commitAll(dir, env, msg) {
  git(dir, ["add", "-A"], env);
  return git(dir, ["commit", "-q", "--allow-empty", "-m", msg], env);
}

/** Files a cone-mode sparse checkout of `subdir` keeps from `files`. */
function coneFiles(files, subdir) {
  if (!subdir) return files;
  const parts = subdir.split("/");
  const parents = new Set([""]);
  for (let i = 1; i < parts.length; i++) parents.add(parts.slice(0, i).join("/"));
  return files.filter((f) => {
    if (f.startsWith(subdir + "/")) return true;
    const dir = f.includes("/") ? f.slice(0, f.lastIndexOf("/")) : "";
    return parents.has(dir);
  });
}

function worktreeFiles(root) {
  const out = [];
  const visit = (dir, rel) => {
    for (const name of fs.readdirSync(dir)) {
      if (rel === "" && (name === ".git" || name === ".worktrees")) continue;
      const abs = path.join(dir, name);
      const r = rel ? `${rel}/${name}` : name;
      if (fs.lstatSync(abs).isDirectory()) visit(abs, r);
      else out.push(r);
    }
  };
  visit(root, "");
  return out.sort();
}

function manifestText(repos) {
  return repos
    .map((r) =>
      [
        "[[repo]]",
        `name = "${r.name}"`,
        `path = "${r.path}"`,
        `url = "${r.url}"`,
        ...(r.subdir ? [`subdir = "${r.subdir}"`] : []),
        "",
      ].join("\n"),
    )
    .join("\n");
}

export function runHome(ctx, steps) {
  const { root, bit, env, rng, log } = ctx;
  const bitRun = (cwd, args) => {
    const r = run(bit, ["-C", cwd, ...args], { env: { ...env, PWD: cwd } });
    log.push(`$ bit ${args.join(" ")}   # in ${path.relative(root, cwd) || "."} -> ${r.code}`);
    return r;
  };
  const home = path.join(root, "home");
  const init = bitRun(root, ["home", "init", home]);
  if (init.code !== 0) return { step: 0, problems: [`bit home init failed: ${init.stderr}`] };
  git(home, ["add", "-A"], env);
  git(home, ["commit", "-q", "-m", "home"], env);

  // Upstreams: bare repo + a seed clone that pushes to it.
  const repos = [];
  const nRepos = 2 + rng.int(2);
  for (let i = 0; i < nRepos; i++) {
    const name = `r${i}`;
    const bare = path.join(root, "up", `${name}.git`);
    const seed = path.join(root, "seed", name);
    git(root, ["init", "-q", "--bare", "-b", "main", bare], env);
    git(root, ["clone", "-q", bare, seed], env);
    for (const f of UP_FILES) {
      fs.mkdirSync(path.dirname(path.join(seed, f)), { recursive: true });
      fs.writeFileSync(path.join(seed, f), `${name} ${f} 0\n`);
    }
    commitAll(seed, env, "init");
    git(seed, ["push", "-q", "origin", "main"], env);
    repos.push({ name, bare, seed, url: `file://${bare}`, path: `../members/${name}`, subdir: rng.pick(SUBDIRS) });
  }
  fs.writeFileSync(path.join(home, "bit-home.toml"), manifestText(repos));
  bitRun(home, ["home", "render"]);
  const memberDir = (r) => path.resolve(home, r.path);

  const problems = [];
  const check = (cond, msg) => {
    if (!cond) problems.push(msg);
  };

  for (let step = 0; step < steps; step++) {
    const roll = rng.int(100);
    const r = rng.pick(repos);
    const dir = memberDir(r);
    const cloned = fs.existsSync(path.join(dir, ".git"));
    if (roll < 25) {
      // Upstream moves: touch a random file (in or out of any cone).
      const f = rng.pick(UP_FILES);
      fs.writeFileSync(path.join(r.seed, f), `${r.name} ${f} ${step}\n`);
      commitAll(r.seed, env, `up ${step}`);
      git(r.seed, ["push", "-q", "origin", "main"], env);
      log.push(`# upstream ${r.name}: change ${f}`);
    } else if (roll < 35 && cloned) {
      // Local commit (diverges if upstream also moved).
      const f = path.join(dir, `local-${step}.txt`);
      fs.writeFileSync(f, "local\n");
      commitAll(dir, env, `local ${step}`);
      log.push(`# ${r.name}: local commit`);
    } else if (roll < 45 && cloned) {
      // Dirty tracked edit, or an untracked file.
      const tracked = (gitOut(dir, ["ls-files"], env) ?? "").split("\n").filter(Boolean);
      const present = tracked.filter((t) => fs.existsSync(path.join(dir, t)));
      if (present.length && rng.chance(0.6)) {
        const t = rng.pick(present);
        fs.appendFileSync(path.join(dir, t), `dirty ${step}\n`);
        log.push(`# ${r.name}: dirty edit ${t}`);
      } else {
        fs.writeFileSync(path.join(dir, `untracked-${step}`), "u\n");
        log.push(`# ${r.name}: untracked file`);
      }
    } else if (roll < 52 && cloned) {
      // Clean up: commit or discard local changes.
      if (rng.chance(0.5)) {
        commitAll(dir, env, `wip ${step}`);
        log.push(`# ${r.name}: commit wip`);
      } else {
        git(dir, ["checkout", "--", "."], env);
        git(dir, ["clean", "-fdq", "-e", ".worktrees"], env);
        log.push(`# ${r.name}: discard changes`);
      }
    } else if (roll < 58) {
      // Re-point the sparse cone (or drop it).
      r.subdir = rng.pick(SUBDIRS);
      fs.writeFileSync(path.join(home, "bit-home.toml"), manifestText(repos));
      const rr = bitRun(home, ["home", "render", "--check"]);
      check(rr.code === 1 || rr.code === 0, `render --check exited ${rr.code}`);
      bitRun(home, ["home", "render"]);
      log.push(`# manifest: ${r.name}.subdir = ${r.subdir}`);
    } else if (roll < 63 && cloned) {
      const feature = `feat${step}`;
      const w = bitRun(home, ["home", "wt", "add", r.name, feature]);
      if (w.code === 0) {
        const wt = path.join(dir, ".worktrees", feature);
        check(fs.existsSync(wt), `wt add ${r.name} ${feature}: worktree missing`);
        const st = gitOut(dir, ["status", "--porcelain"], env) ?? "";
        check(!st.includes(".worktrees"), `wt add: .worktrees shows up in status of ${r.name}`);
        if (rng.chance(0.5)) {
          const rm = bitRun(home, ["home", "wt", "remove", r.name, feature]);
          check(rm.code === 0, `wt remove ${r.name} ${feature} failed: ${rm.stderr.trim()}`);
        }
      }
    } else {
      // Sync everything (or one repo) and check the invariants.
      const targets = rng.chance(0.2) ? [r] : repos;
      const before = new Map();
      for (const t of targets) {
        const d = memberDir(t);
        if (!fs.existsSync(path.join(d, ".git"))) {
          before.set(t.name, { missing: true });
          continue;
        }
        const head = gitOut(d, ["rev-parse", "HEAD"], env)?.trim();
        const tracked = (gitOut(d, ["status", "--porcelain", "--untracked-files=no"], env) ?? "").trim();
        const contents = new Map();
        if (tracked) {
          for (const f of worktreeFiles(d)) contents.set(f, fs.readFileSync(path.join(d, f)).toString("hex"));
        }
        before.set(t.name, {
          head,
          dirty: tracked.length > 0,
          merges: (gitOut(d, ["rev-list", "--merges", "HEAD"], env) ?? "").trim(),
          contents,
        });
      }
      const s = bitRun(home, ["home", "sync", ...(targets.length === 1 ? [r.name] : [])]);
      let diverged = false;
      for (const t of targets) {
        const d = memberDir(t);
        const b = before.get(t.name);
        const upTip = gitOut(t.bare, ["rev-parse", "main"], env)?.trim();
        if (!fs.existsSync(path.join(d, ".git"))) {
          problems.push(`${t.name}: still not cloned after sync (exit ${s.code}): ${s.stderr.trim()}`);
          continue;
        }
        const head = gitOut(d, ["rev-parse", "HEAD"], env)?.trim();
        const f = fsckProblem(d, env);
        if (f) problems.push(`${t.name}: ${f}`);
        if (b.missing) {
          check(head === upTip, `${t.name}: fresh clone at ${head}, upstream is ${upTip}`);
        } else {
          check(
            git(d, ["merge-base", "--is-ancestor", b.head, head], env).code === 0,
            `${t.name}: local commit ${b.head} lost (HEAD now ${head})`,
          );
          check(
            (gitOut(d, ["rev-list", "--merges", "HEAD"], env) ?? "").trim() === b.merges,
            `${t.name}: sync created a merge commit`,
          );
          if (b.dirty) {
            check(head === b.head, `${t.name}: dirty repo was updated (${b.head} -> ${head})`);
            for (const [file, hex] of b.contents) {
              const p = path.join(d, file);
              const now = fs.existsSync(p) ? fs.readFileSync(p).toString("hex") : "(deleted)";
              check(now === hex, `${t.name}: local content of ${file} changed by sync`);
            }
          } else {
            const ff = git(d, ["merge-base", "--is-ancestor", b.head, upTip], env).code === 0;
            if (ff) {
              check(head === upTip, `${t.name}: clean fast-forwardable repo at ${head}, upstream ${upTip}`);
            } else {
              diverged = true;
              check(head === b.head, `${t.name}: diverged repo was changed (${b.head} -> ${head})`);
            }
          }
        }
        // Sparse cone matches the manifest (only meaningful when clean).
        const clean = (gitOut(d, ["status", "--porcelain"], env) ?? "").trim() === "";
        if (clean) {
          const treeFiles = (gitOut(d, ["ls-tree", "-r", "--name-only", "HEAD"], env) ?? "")
            .split("\n")
            .filter(Boolean)
            .sort();
          // untracked-* files are the model's own scratch files; once a
          // "commit wip" step has committed one it is tracked too, so the
          // filter applies to both sides.
          const scratch = (x) => path.basename(x).startsWith("untracked-");
          const expected = coneFiles(treeFiles, t.subdir).filter((x) => !scratch(x)).sort();
          const actual = worktreeFiles(d).filter((x) => !scratch(x));
          check(
            JSON.stringify(actual) === JSON.stringify(expected),
            `${t.name}: checkout does not match subdir=${t.subdir}\n    expected: ${expected.join(" ")}\n    actual:   ${actual.join(" ")}`,
          );
        }
      }
      if (diverged) check(s.code !== 0, `sync exited 0 although a repository diverged`);
      const st = bitRun(home, ["home", "status"]);
      check(st.code === 0, `bit home status exited ${st.code}: ${st.stderr.trim()}`);
    }
    if (problems.length) return { step, problems };
  }
  return { step: steps, problems };
}
