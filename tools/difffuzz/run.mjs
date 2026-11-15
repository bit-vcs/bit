#!/usr/bin/env node
// Differential / model-based fuzzing of bit against real git.
// Opt-in (not run in CI): it can take minutes.
//
//   node tools/difffuzz/run.mjs [--scenario core|worktree|sparse|home|all]
//        [--seeds N | --seed S] [--steps M] [--bit PATH] [--crash P]
//        [--keep] [--out DIR]
//
// Each failure prints the scenario, seed and step plus the operation log,
// and keeps the repositories under --out for inspection. Re-running with the
// same --scenario/--seed/--steps reproduces it exactly.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { makeEnv, makeRng, Pair, run } from "./lib.mjs";
import { runHome } from "./home.mjs";
import { runCore, runSparse, runWorktree } from "./scenarios.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../..");

function parseArgs(argv) {
  const o = {
    scenario: "all",
    seeds: 10,
    seed: null,
    steps: 40,
    bit: path.join(repoRoot, "_build/native/release/build/mizchi/bit/bit.exe"),
    crash: 0,
    keep: false,
    out: path.join(os.tmpdir(), "bit-difffuzz"),
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const v = () => argv[++i];
    if (a === "--scenario") o.scenario = v();
    else if (a === "--seeds") o.seeds = Number(v());
    else if (a === "--seed") o.seed = Number(v());
    else if (a === "--steps") o.steps = Number(v());
    else if (a === "--bit") o.bit = path.resolve(v());
    else if (a === "--crash") o.crash = Number(v());
    else if (a === "--keep") o.keep = true;
    else if (a === "--out") o.out = path.resolve(v());
    else if (a === "-h" || a === "--help") {
      console.log(fs.readFileSync(fileURLToPath(import.meta.url), "utf8").split("\n").slice(1, 12).join("\n"));
      process.exit(0);
    } else {
      console.error(`unknown option ${a}`);
      process.exit(2);
    }
  }
  return o;
}

const SCENARIOS = {
  core: (pair, steps) => runCore(pair, steps),
  worktree: (pair, steps) => runWorktree(pair, steps),
  sparse: (pair, steps) => runSparse(pair, steps),
  home: (pair, steps) => runHome(pair, steps),
};

function main() {
  const o = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(o.bit)) {
    console.error(`bit binary not found: ${o.bit}\nbuild it with: moon build --target native --release modules/bit`);
    process.exit(2);
  }
  const names = o.scenario === "all" ? Object.keys(SCENARIOS) : o.scenario.split(",");
  for (const n of names) {
    if (!SCENARIOS[n]) {
      console.error(`unknown scenario ${n} (expected ${Object.keys(SCENARIOS).join(", ")}, all)`);
      process.exit(2);
    }
  }
  const seeds = o.seed !== null ? [o.seed] : Array.from({ length: o.seeds }, (_, i) => 1000 + i);
  fs.mkdirSync(o.out, { recursive: true });
  const gitVersion = run("git", ["--version"], {}).stdout.trim();
  console.log(`bit: ${o.bit}\n${gitVersion}\nout: ${o.out}\n`);

  const failures = [];
  let runs = 0;
  let crashes = 0;
  const t0 = Date.now();
  for (const scenario of names) {
    for (const seed of seeds) {
      runs++;
      const root = path.join(o.out, `${scenario}-${seed}`);
      fs.rmSync(root, { recursive: true, force: true });
      fs.mkdirSync(root, { recursive: true });
      const env = makeEnv(path.join(root, "home-dir"));
      const rng = makeRng(seed * 7919 + scenario.length);
      const log = [];
      const ctx = scenario === "home"
        ? { root, bit: o.bit, env, rng, log }
        : new Pair({ root, bit: o.bit, env, crash: o.crash, rng, log });
      let result;
      try {
        result = SCENARIOS[scenario](ctx, o.steps);
      } catch (e) {
        result = { step: -1, problems: [`harness error: ${e.stack ?? e}`] };
      }
      if (result.crashed) crashes++;
      const ok = result.problems.length === 0;
      process.stdout.write(
        `${ok ? "ok  " : "FAIL"} ${scenario} seed=${seed} steps=${result.step}${result.crashed ? " (crash-recovery)" : ""}\n`,
      );
      if (!ok) {
        const report = [
          `scenario=${scenario} seed=${seed} failed at step ${result.step}`,
          `reproduce: node tools/difffuzz/run.mjs --scenario ${scenario} --seed ${seed} --steps ${o.steps}${o.crash ? ` --crash ${o.crash}` : ""} --keep`,
          "",
          ...result.problems,
          "",
          "operation log (last 30):",
          ...log.slice(-30).map((l) => `  ${l}`),
        ].join("\n");
        fs.writeFileSync(path.join(root, "FAILURE.txt"), report + "\n");
        failures.push(report);
      } else if (!o.keep) {
        fs.rmSync(root, { recursive: true, force: true });
      }
    }
  }
  const secs = ((Date.now() - t0) / 1000).toFixed(1);
  console.log(`\n${runs - failures.length}/${runs} runs passed (${crashes} crash-recovery runs) in ${secs}s`);
  for (const f of failures) console.log(`\n---\n${f}`);
  process.exit(failures.length ? 1 : 0);
}

main();
