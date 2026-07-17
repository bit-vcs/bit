#!/usr/bin/env node
// Select the moon test targets and git-compat suites affected by a change.
//
// Sources of truth:
//   - moon.work + modules/*/moon.mod        → module graph (reverse-dep closure)
//   - tools/flaker-affected-rules.mjs       → changed path → git-compat suites
//   - tools/git-test-allowlist.txt          → the universe of git-compat suites
//
// Usage:
//   node tools/select-affected-tests.mjs --base origin/main [--head HEAD]
//   node tools/select-affected-tests.mjs --changed a.mbt --changed b.mbt
//   ... [--json | --github]      (--json is the default output format)
//
// Output (JSON):
//   {
//     full: bool,            // run everything (infra change or unmapped file)
//     reasons: [...],        // why full was triggered, if it was
//     modules: [...],        // affected module dirs (dependency closure)
//     moon_targets: [...],   // moon test -p targets for native module tests
//     cmd_bit: bool,         // whether cmd/bit native shards must run
//     git_tests: [...],      // git-compat suites (relative to third_party/git/t)
//   }
//
// `--github` additionally appends step outputs to $GITHUB_OUTPUT.

import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, existsSync, appendFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import {
  GIT_COMPAT_AFFECTED_RULES,
  selectSuitesForChanges,
  fileHasRule,
} from "./flaker-affected-rules.mjs";

// Changes to these paths cannot be mapped to a subset — run everything.
const FULL_TRIGGERS = [
  /^moon\.work$/,
  /^Taskfile\.pkl$/,
  /^\.github\//,
  /^third_party\//,
  /^tools\/git-patches\//,
  /^tools\/git-test-allowlist\.txt$/,
  /^tools\/git-test-runtime-seconds\.tsv$/,
  /^tools\/select-affected-tests\.mjs$/,
  /^tools\/flaker-affected-rules\.mjs$/,
  /^flake\.(nix|lock)$/,
  /^package\.nix$/,
  /^nix\//,
];

// Changes to these paths affect no tests at all (docs, editor config, ...).
const NO_TEST_PATHS = [
  /^docs\//,
  /^\.claude\//,
  /\.md$/,
  /^AGENTS\.md$/,
  /^LICENSE$/,
  /^t\//, // bit's own e2e harness runs in its own job, not selected here
  /^e2e\//,
  /^npm\//,
  /^playground\//,
  /^fixtures\//,
  /^pkspec\//,
  /^component\//,
  /^dir$/,
  /^file\.txt$/,
];

export function parseWorkspaceModules(root) {
  const work = readFileSync(`${root}/moon.work`, "utf8");
  const members = [...work.matchAll(/"\.\/([^"]+)"/g)].map((m) => m[1]);
  return members;
}

export function parseModuleGraph(root, members) {
  // moduleName (mizchi/<x>) -> { dir, deps: [moduleName] }
  const byName = new Map();
  for (const dir of members) {
    const modFile = `${root}/${dir}/moon.mod`;
    if (!existsSync(modFile)) continue;
    const text = readFileSync(modFile, "utf8");
    const name = text.match(/name = "([^"]+)"/)?.[1];
    if (!name) continue;
    const deps = [...text.matchAll(/"(mizchi\/[a-z0-9_]+)@/g)]
      .map((m) => m[1]);
    byName.set(name, { dir, deps });
  }
  return byName;
}

export function reverseClosure(graph, seedNames) {
  // dependents: name -> [names that import it]
  const dependents = new Map();
  for (const [name, { deps }] of graph) {
    for (const dep of deps) {
      if (!graph.has(dep)) continue; // external mooncakes dep
      if (!dependents.has(dep)) dependents.set(dep, []);
      dependents.get(dep).push(name);
    }
  }
  const affected = new Set(seedNames);
  const queue = [...seedNames];
  while (queue.length > 0) {
    const cur = queue.pop();
    for (const dependent of dependents.get(cur) ?? []) {
      if (!affected.has(dependent)) {
        affected.add(dependent);
        queue.push(dependent);
      }
    }
  }
  return affected;
}

export function moduleForPath(members, file) {
  // Longest matching member dir wins (modules/bit vs modules/bit_lib).
  let best = null;
  for (const dir of members) {
    if (file.startsWith(`${dir}/`) && (!best || dir.length > best.length)) {
      best = dir;
    }
  }
  return best;
}

export function loadSuites(root) {
  const text = readFileSync(`${root}/tools/git-test-allowlist.txt`, "utf8");
  return text
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"))
    .map((l) => (l.startsWith("third_party/") ? l : `third_party/git/t/${l}`));
}

export function selectAffected(root, changedFiles) {
  const reasons = [];
  let full = false;

  const changed = changedFiles
    .map((f) => f.replaceAll("\\", "/"))
    .filter((f) => f.length > 0);

  for (const f of changed) {
    if (FULL_TRIGGERS.some((re) => re.test(f))) {
      full = true;
      reasons.push(`infra: ${f}`);
    }
  }

  const members = parseWorkspaceModules(root);
  const graph = parseModuleGraph(root, members);
  const dirToName = new Map(
    [...graph.entries()].map(([name, { dir }]) => [dir, name]),
  );

  const seedNames = new Set();
  const relevant = [];
  for (const f of changed) {
    if (NO_TEST_PATHS.some((re) => re.test(f))) continue;
    const dir = moduleForPath(members, f);
    if (dir) {
      relevant.push(f);
      const name = dirToName.get(dir);
      if (name) seedNames.add(name);
      // Safety net: a module file no git-test rule knows about → full run.
      if (!fileHasRule(f, GIT_COMPAT_AFFECTED_RULES)) {
        full = true;
        reasons.push(`unmapped: ${f}`);
      }
    } else if (f.startsWith("tools/")) {
      // Unlisted tools scripts don't affect bit itself.
      continue;
    } else if (!FULL_TRIGGERS.some((re) => re.test(f))) {
      // Unknown top-level file: be safe.
      full = true;
      reasons.push(`unknown: ${f}`);
    }
  }

  const affectedNames = reverseClosure(graph, [...seedNames]);
  const modules = [...affectedNames]
    .map((n) => graph.get(n)?.dir)
    .filter(Boolean)
    .sort();

  const cmdBit = full || affectedNames.has("mizchi/bit");
  const moonTargets = [];
  for (const name of [...affectedNames].sort()) {
    if (name === "mizchi/bit") {
      moonTargets.push("mizchi/bit/tests");
    } else {
      moonTargets.push(name);
    }
  }

  const suites = loadSuites(root);
  const gitTests = full
    ? suites
    : selectSuitesForChanges(relevant, suites, GIT_COMPAT_AFFECTED_RULES);

  return {
    full,
    reasons,
    modules,
    moon_targets: full ? ["ALL"] : moonTargets,
    cmd_bit: cmdBit,
    git_tests: gitTests,
  };
}

function gitChangedFiles(root, base, head) {
  const out = execFileSync(
    "git",
    ["diff", "--name-only", `${base}...${head}`],
    { cwd: root, encoding: "utf8" },
  );
  return out.split("\n").filter(Boolean);
}

function main() {
  const args = process.argv.slice(2);
  const root = process.cwd();
  let base = null;
  let head = "HEAD";
  const changed = [];
  let github = false;
  let forceFull = false;
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--base":
        base = args[++i];
        break;
      case "--head":
        head = args[++i];
        break;
      case "--changed":
        changed.push(args[++i]);
        break;
      case "--github":
        github = true;
        break;
      case "--full":
        forceFull = true;
        break;
      case "--json":
        break;
      default:
        console.error(`unknown argument: ${args[i]}`);
        process.exit(2);
    }
  }

  const files = base ? gitChangedFiles(root, base, head) : changed;
  let result = selectAffected(root, files);
  if (forceFull) {
    const suites = loadSuites(root);
    result = {
      ...result,
      full: true,
      reasons: ["forced"],
      moon_targets: ["ALL"],
      cmd_bit: true,
      git_tests: suites,
    };
  }

  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);

  if (github && process.env.GITHUB_OUTPUT) {
    // git_tests entries use the allowlist's bare-basename format so the list
    // can be fed straight back into tools/select-git-tests.sh for sharding.
    const bare = result.git_tests.map((t) =>
      t.replace(/^third_party\/git\/t\//, ""),
    );
    const lines = [
      `full=${result.full}`,
      `cmd_bit=${result.cmd_bit}`,
      `moon_targets=${result.moon_targets.join(" ")}`,
      `git_test_count=${result.git_tests.length}`,
      "git_tests<<GIT_TESTS_EOF",
      ...bare,
      "GIT_TESTS_EOF",
    ];
    appendFileSync(process.env.GITHUB_OUTPUT, `${lines.join("\n")}\n`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
