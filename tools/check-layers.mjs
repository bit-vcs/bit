#!/usr/bin/env node
// Validate that mizchi/bit packages follow the layered dependency rules
// documented in docs/package-layout.md.
//
// Usage: node tools/check-layers.mjs
//
// Exit codes: 0 = clean, 1 = violations found.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(fileURLToPath(import.meta.url), "..", "..");
const SRC = join(REPO_ROOT, "src");
const MODULE_PREFIX = "mizchi/bit";

// Layer order (low to high). A package may import from its own layer or any
// lower layer.
const LAYERS = ["core", "mid", "high", "ext", "cmd"];
const LAYER_ORDER = Object.fromEntries(LAYERS.map((l, i) => [l, i]));

// Pure plumbing. Does not depend on `lib`.
const CORE = new Set([
  "", // root mizchi/bit (re-exports core types)
  "types",
  "hash",
  "date_parse",
  "string_utils",
  "config_parse",
  "object",
  "trailers",
  "ignore",
  "tar",
  "diff_core",
  "diff3",
  "apply",
  "fast_import",
  "io",
  "osfs",
  "pack",
  "refs",
  "reftable",
  "protocol",
  "bootstrap",
  "remote",
  "repo",
]);

// Aspirationally mid (gitoxide-core-equivalent), currently empty as the
// carved-out operation packages still depend back on `lib` and are tracked
// under `high`. New packages without a `lib` dependency may go here.
const MID = new Set([]);

// Porcelain — `lib` itself plus packages carved out of `lib` that still
// depend on it. Migration target: shrink this set toward `mid`.
const HIGH = new Set([
  "lib",
  "diff",
  "grep",
  "runtime",
  "pack_ops",
  "repo_ops",
  "worktree",
]);

// Foundational ext-* packages that other ext-* packages and `lib` are allowed
// to depend on. These are essentially infrastructure; long-term they should be
// promoted out of `ext`. See docs/package-layout.md.
const EXT_SHARED = new Set([
  "x-fs",
  "x-fingerprint",
]);

function isOurModule(pkgPath) {
  return pkgPath === MODULE_PREFIX || pkgPath.startsWith(MODULE_PREFIX + "/");
}

// Map a package path (e.g. "mizchi/bit/hash") to its layer.
function classify(pkgPath) {
  if (!isOurModule(pkgPath)) return null; // external
  const rel = pkgPath === MODULE_PREFIX ? "" : pkgPath.slice(MODULE_PREFIX.length + 1);
  const top = rel.split("/")[0];
  if (rel === "") return "core";
  if (top === "cmd" || top === "tests" || top === "fuzz_tests") return "cmd";
  if (top.startsWith("x-")) return "ext";
  if (CORE.has(top)) return "core";
  if (MID.has(top)) return "mid";
  if (HIGH.has(top)) return "high";
  return "unknown";
}

function topSegment(pkgPath) {
  if (!isOurModule(pkgPath)) return null;
  if (pkgPath === MODULE_PREFIX) return "";
  return pkgPath.slice(MODULE_PREFIX.length + 1).split("/")[0];
}

function* walkPkgFiles(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    const st = statSync(full);
    if (st.isDirectory()) {
      yield* walkPkgFiles(full);
    } else if (name === "moon.pkg" || name === "moon.pkg.json") {
      yield full;
    }
  }
}

// Derive the package path "mizchi/bit/<rel-of-src>" from a moon.pkg location.
function pkgPathOf(moonPkgFile) {
  const dir = moonPkgFile.replace(/\/(moon\.pkg|moon\.pkg\.json)$/, "");
  const rel = relative(SRC, dir);
  if (rel === "" || rel === ".") return MODULE_PREFIX;
  return MODULE_PREFIX + "/" + rel.split("\\").join("/");
}

// Extract imported package paths from a moon.pkg / moon.pkg.json file.
function extractImports(file) {
  const text = readFileSync(file, "utf8");
  const out = [];
  if (file.endsWith(".json")) {
    try {
      const j = JSON.parse(text);
      const imp = j.import || [];
      const tst = j["test-import"] || [];
      const wb = j["wbtest-import"] || [];
      for (const i of [...imp, ...tst, ...wb]) {
        if (typeof i === "string") out.push(i);
        else if (i && typeof i.path === "string") out.push(i.path);
      }
    } catch {
      /* ignore */
    }
  } else {
    // moon.pkg uses Lua-ish syntax: import { "foo/bar" @alias, ... }
    const re = /"([^"\n]+)"/g;
    let m;
    while ((m = re.exec(text)) !== null) {
      const s = m[1];
      if (s.includes("/") || s === MODULE_PREFIX) out.push(s);
    }
  }
  return out;
}

const violations = [];

for (const file of walkPkgFiles(SRC)) {
  const fromPath = pkgPathOf(file);
  const fromLayer = classify(fromPath);
  if (fromLayer === null || fromLayer === "unknown") {
    violations.push({
      kind: "unknown-source",
      file,
      from: fromPath,
      msg: `package ${fromPath} is not classified into a layer`,
    });
    continue;
  }

  for (const dep of extractImports(file)) {
    if (!isOurModule(dep)) continue; // external dep
    if (dep === fromPath) continue;
    const toLayer = classify(dep);
    if (toLayer === null || toLayer === "unknown") {
      violations.push({
        kind: "unknown-target",
        file,
        from: fromPath,
        to: dep,
        msg: `target package ${dep} is not classified into a layer`,
      });
      continue;
    }
    const toTop = topSegment(dep);
    const fromTop = topSegment(fromPath);
    const toIsExtShared = toLayer === "ext" && EXT_SHARED.has(toTop);

    // Allow `high` (lib) and `ext` to import shared-infrastructure ext packages.
    if (toIsExtShared && (fromLayer === "high" || fromLayer === "ext" || fromLayer === "cmd")) {
      // OK
    } else if (LAYER_ORDER[fromLayer] < LAYER_ORDER[toLayer]) {
      violations.push({
        kind: "upward",
        file,
        from: fromPath,
        fromLayer,
        to: dep,
        toLayer,
        msg: `${fromLayer} package ${fromPath} imports ${toLayer} package ${dep}`,
      });
    }

    // ext-to-ext rule: ext packages cannot depend on other ext-* families,
    // unless the target is in the EXT_SHARED allowlist.
    if (fromLayer === "ext" && toLayer === "ext" && !toIsExtShared) {
      if (fromTop !== toTop) {
        violations.push({
          kind: "ext-to-ext",
          file,
          from: fromPath,
          to: dep,
          msg: `ext package ${fromPath} imports a different ext package ${dep}`,
        });
      }
    }
  }
}

if (violations.length === 0) {
  console.log("OK: package layering is clean");
  process.exit(0);
}

console.error(`Found ${violations.length} layer violation(s):`);
for (const v of violations) {
  console.error(`  [${v.kind}] ${v.msg}`);
  console.error(`    file: ${relative(REPO_ROOT, v.file)}`);
}
process.exit(1);
