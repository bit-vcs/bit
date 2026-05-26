#!/usr/bin/env node
// Validate that mizchi/bit packages follow the layered dependency rules
// documented in docs/package-layout.md.
//
// Usage: node tools/check-layers.mjs
//
// Exit codes: 0 = clean, 1 = violations found.

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(fileURLToPath(import.meta.url), "..", "..");
const MODULES_DIR = join(REPO_ROOT, "modules");
const MODULE_PREFIX = "mizchi/bit";
const EXT_PREFIX = "mizchi/bitx_";
// Standalone core modules extracted out of mizchi/bit. Each one is a
// gix-* plumbing equivalent that lives in its own MoonBit module under
// modules/bit_<name>/. They are still classified as the "core" layer.
const CORE_MODULES = new Set([
  "mizchi/bit_apply",
  "mizchi/bit_archive",
  "mizchi/bit_bootstrap",
  "mizchi/bit_config",
  "mizchi/bit_date",
  "mizchi/bit_diff3",
  "mizchi/bit_diff_core",
  "mizchi/bit_fast_import",
  "mizchi/bit_hash",
  "mizchi/bit_ignore",
  "mizchi/bit_io",
  "mizchi/bit_object",
  "mizchi/bit_osfs",
  "mizchi/bit_pack",
  "mizchi/bit_protocol",
  "mizchi/bit_refs",
  "mizchi/bit_reftable",
  "mizchi/bit_trailers",
  "mizchi/bit_types",
  "mizchi/bit_utils",
]);

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
  "vfs",
  "fingerprint",
]);

function isExtModule(pkgPath) {
  return pkgPath === EXT_PREFIX.slice(0, -1) /* never matches */ ||
         pkgPath.startsWith(EXT_PREFIX);
}

function isCoreModule(pkgPath) {
  const head = pkgPath.split("/").slice(0, 2).join("/");
  return CORE_MODULES.has(head);
}

function isOurModule(pkgPath) {
  if (pkgPath === MODULE_PREFIX || pkgPath.startsWith(MODULE_PREFIX + "/")) return true;
  if (isExtModule(pkgPath)) return true;
  if (isCoreModule(pkgPath)) return true;
  return false;
}

// Map a package path (e.g. "mizchi/bit/hash" or "mizchi/bitx_hub/native")
// to its layer.
function classify(pkgPath) {
  if (!isOurModule(pkgPath)) return null; // external
  if (isExtModule(pkgPath)) return "ext";
  if (isCoreModule(pkgPath)) return "core";
  const rel = pkgPath === MODULE_PREFIX ? "" : pkgPath.slice(MODULE_PREFIX.length + 1);
  const top = rel.split("/")[0];
  if (rel === "") return "core";
  if (top === "cmd" || top === "tests" || top === "fuzz_tests") return "cmd";
  if (CORE.has(top)) return "core";
  if (MID.has(top)) return "mid";
  if (HIGH.has(top)) return "high";
  return "unknown";
}

function topSegment(pkgPath) {
  if (!isOurModule(pkgPath)) return null;
  if (isCoreModule(pkgPath)) {
    return pkgPath.split("/").slice(0, 2).join("/");
  }
  if (isExtModule(pkgPath)) {
    // For ext modules, the "family" is the module name itself
    // (e.g. "mizchi/bitx_hub" is one family — its sub-packages /native,
    // /crypto are the same family).
    return pkgPath.split("/").slice(0, 2).join("/");
  }
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

// Roots to walk. Each root maps a moon.pkg file to a package path:
//   { dir, prefix }  →  package path = prefix + ("" or "/<rel>")
function discoverRoots() {
  const roots = [];
  if (existsSync(MODULES_DIR)) {
    for (const name of readdirSync(MODULES_DIR)) {
      const modSrc = join(MODULES_DIR, name, "src");
      if (existsSync(modSrc)) {
        roots.push({ dir: modSrc, prefix: `mizchi/${name}` });
      }
    }
  }
  return roots;
}

// Derive the package path from a moon.pkg location for a given root.
function pkgPathOf(moonPkgFile, root) {
  const dir = moonPkgFile.replace(/\/(moon\.pkg|moon\.pkg\.json)$/, "");
  const rel = relative(root.dir, dir);
  if (rel === "" || rel === ".") return root.prefix;
  return root.prefix + "/" + rel.split("\\").join("/");
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

const roots = discoverRoots();
const files = [];
for (const root of roots) {
  for (const file of walkPkgFiles(root.dir)) {
    files.push({ file, root });
  }
}

for (const { file, root } of files) {
  const fromPath = pkgPathOf(file, root);
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

    if (LAYER_ORDER[fromLayer] < LAYER_ORDER[toLayer]) {
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

    // ext-to-ext rule: ext packages cannot depend on other ext-* families.
    if (fromLayer === "ext" && toLayer === "ext" && fromTop !== toTop) {
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
