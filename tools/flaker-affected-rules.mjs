import { pathToFileURL } from "node:url";

// Mapping from changed paths to the git-compat suites they can affect.
//
// Two layers of rules:
//   1. Module-level rules (`modules/<name>/**`) — every workspace module maps
//      to the git test areas its subsystem implements. Foundational modules
//      (object store, IO, core types) map to the full suite.
//   2. File-level rules for the two kitchen-sink packages
//      (`modules/bit/cmd/bit/*.mbt`, `modules/bit_lib/src/*.mbt`) — these
//      carve command areas out of packages that would otherwise select
//      everything.
//
// Matching is additive: a changed file selects the union of all rules it
// matches. Changed files under `modules/**` that match NO rule are treated by
// the selector (tools/select-affected-tests.mjs) as "run the full suite" — a
// safety net for new modules and unmapped files, so an incomplete map fails
// towards over-testing, never under-testing.
//
// tools/flaker-affected-rules.toml is generated from this file:
//   node tools/flaker-affected-rules.mjs > tools/flaker-affected-rules.toml

const FULL_SUITE = ["third_party/git/t/*.sh"];

export const GIT_COMPAT_AFFECTED_RULES = [
  // ---- infrastructure: anything here invalidates every suite -------------
  {
    reason: "infrastructure",
    changed: [
      "modules/bit/moon.mod",
      "modules/bit/moon.pkg",
      "modules/bit/top.mbt",
      "modules/bit/main.mbt",
      "modules/bit/cmd/bit/main*.mbt",
      "modules/bit/cmd/bit/helpers*.mbt",
      "modules/bit/cmd/bit/fallback*.mbt",
      "tools/git-shim/**",
      "tools/run-git-test.sh",
      "tools/apply-git-test-patches.sh",
      "tools/select-git-tests.sh",
      "tools/flaker-run-git-compat-tests.mjs",
    ],
    select: FULL_SUITE,
  },
  {
    reason: "module:foundation",
    changed: [
      "modules/bit_core/**",
      "modules/bit_types/**",
      "modules/bit_object/**",
      "modules/bit_hash/**",
      "modules/bit_io/**",
      "modules/bit_io_native/**",
      "modules/bit_osfs/**",
      "modules/bit_vfs/**",
      "modules/bit_runtime/**",
      "modules/bit_utils/**",
      "modules/bit_bootstrap/**",
    ],
    select: FULL_SUITE,
  },

  // ---- module-level areas -------------------------------------------------
  {
    reason: "module:config",
    changed: ["modules/bit_config/**", "modules/bitx_bitconfig/**"],
    select: ["third_party/git/t/t13*.sh", "third_party/git/t/t0007-git-var.sh"],
  },
  {
    reason: "module:refs",
    changed: ["modules/bit_refs/**", "modules/bit_reftable/**"],
    select: [
      "third_party/git/t/t14*.sh",
      "third_party/git/t/t32*.sh",
      "third_party/git/t/t63*.sh",
      "third_party/git/t/t1401-symbolic-ref.sh",
      "third_party/git/t/t1403-show-ref.sh",
    ],
  },
  {
    reason: "module:repo",
    changed: ["modules/bit_repo/**", "modules/bit_repo_ops/**"],
    select: [
      "third_party/git/t/t15*.sh",
      "third_party/git/t/t60*.sh",
      "third_party/git/t/t61*.sh",
    ],
  },
  {
    reason: "module:diff",
    changed: [
      "modules/bit_diff/**",
      "modules/bit_diff_core/**",
      "modules/bit_diff3/**",
    ],
    select: [
      "third_party/git/t/t40*.sh",
      "third_party/git/t/t6427-diff3-conflict-markers.sh",
    ],
  },
  {
    reason: "module:apply",
    changed: ["modules/bit_apply/**"],
    select: [
      "third_party/git/t/t41*.sh",
      "third_party/git/t/t3400-rebase.sh",
      "third_party/git/t/t4254-am-corrupt.sh",
    ],
  },
  {
    reason: "module:pack",
    changed: [
      "modules/bit_pack/**",
      "modules/bit_pack_ops/**",
      "modules/bit_fingerprint/**",
    ],
    select: [
      "third_party/git/t/t53*.sh",
      "third_party/git/t/t6113-rev-list-bitmap-filters.sh",
      "third_party/git/t/t6114-keep-packs.sh",
      "third_party/git/t/t7700-repack.sh",
    ],
  },
  {
    reason: "module:transport",
    changed: [
      "modules/bit_protocol/**",
      "modules/bit_remote/**",
      "modules/bit_fast_import/**",
    ],
    select: [
      "third_party/git/t/t55*.sh",
      "third_party/git/t/t57*.sh",
      "third_party/git/t/t93*.sh",
    ],
  },
  {
    reason: "module:worktree",
    changed: ["modules/bit_worktree/**"],
    select: ["third_party/git/t/t24*.sh", "third_party/git/t/t74*.sh"],
  },
  {
    reason: "module:grep",
    changed: ["modules/bit_grep/**"],
    select: ["third_party/git/t/t781*.sh"],
  },
  {
    reason: "module:ignore",
    changed: ["modules/bit_ignore/**"],
    select: [
      "third_party/git/t/t0008-ignores.sh",
      "third_party/git/t/t7011-skip-worktree-reading.sh",
      "third_party/git/t/t7012-skip-worktree-writing.sh",
      "third_party/git/t/t7061-wtstatus-ignore.sh",
    ],
  },
  {
    reason: "module:archive",
    changed: ["modules/bit_archive/**"],
    select: ["third_party/git/t/t500*.sh"],
  },
  {
    reason: "module:trailers",
    changed: ["modules/bit_trailers/**"],
    select: ["third_party/git/t/t7513-interpret-trailers.sh"],
  },
  {
    reason: "module:date",
    changed: ["modules/bit_date/**"],
    select: ["third_party/git/t/t0006-date.sh"],
  },
  {
    reason: "module:signing",
    changed: ["modules/bitx_openpgp/**"],
    select: [
      "third_party/git/t/t7004-tag.sh",
      "third_party/git/t/t7030-verify-tag.sh",
      "third_party/git/t/t7031-verify-tag-signed-ssh.sh",
      "third_party/git/t/t7510-signed-commit.sh",
      "third_party/git/t/t7528-signed-commit-ssh.sh",
    ],
  },
  {
    reason: "module:bit-only",
    // bit-specific extension modules and non-git-compat test trees: no
    // git-compat impact. An explicit empty selection keeps the selector's
    // safety net from escalating these to a full run.
    changed: [
      "modules/bitx_hub/**",
      "modules/bitx_kv/**",
      "modules/bitx_workspace/**",
      "modules/bitx_doc/**",
      "modules/bitx_hq/**",
      "modules/bitx_subdir/**",
      "modules/bitx_rebase_ai/**",
      "modules/bit/cmd/git-bit/**",
      "modules/bit/tests/**",
      "modules/bit/fuzz_tests/**",
    ],
    select: [],
  },

  // ---- file-level rules: modules/bit/cmd/bit + modules/bit_lib -----------
  {
    reason: "command:setup",
    changed: [
      "modules/bit/cmd/bit/init*.mbt",
      "modules/bit/cmd/bit/config*.mbt",
      "modules/bit/cmd/bit/gitconfig*.mbt",
      "modules/bit/cmd/bit/show_ref.mbt",
      "modules/bit/cmd/bit/symbolic_ref.mbt",
      "modules/bit/cmd/bit/rev_parse*.mbt",
      "modules/bit/cmd/bit/hash_object*.mbt",
      "modules/bit/cmd/bit/cat_file*.mbt",
    ],
    select: [
      "third_party/git/t/t0000-basic.sh",
      "third_party/git/t/t0001-init.sh",
      "third_party/git/t/t0012-help.sh",
      "third_party/git/t/t0450-txt-doc-vs-help.sh",
      "third_party/git/t/t1006-cat-file.sh",
      "third_party/git/t/t1007-hash-object.sh",
      "third_party/git/t/t1300-config.sh",
      "third_party/git/t/t1401-symbolic-ref.sh",
      "third_party/git/t/t1403-show-ref.sh",
      "third_party/git/t/t1500-rev-parse.sh",
    ],
  },
  {
    reason: "command:refs",
    changed: [
      "modules/bit/cmd/bit/update_ref.mbt",
      "modules/bit/cmd/bit/pack_refs.mbt",
      "modules/bit/cmd/bit/reflog*.mbt",
      "modules/bit/cmd/bit/for_each_ref.mbt",
      "modules/bit/cmd/bit/check_ref_format.mbt",
    ],
    select: [
      "third_party/git/t/t14*.sh",
      "third_party/git/t/t63*.sh",
      "third_party/git/t/t32*.sh",
    ],
  },
  {
    reason: "command:checkout",
    changed: [
      "modules/bit/cmd/bit/checkout*.mbt",
      "modules/bit/cmd/bit/switch*.mbt",
      "modules/bit/cmd/bit/restore*.mbt",
      "modules/bit/cmd/bit/checkout_index.mbt",
      "modules/bit_lib/src/checkout*.mbt",
      "modules/bit_lib/src/path.mbt",
    ],
    select: [
      "third_party/git/t/t2006-checkout-index-basic.sh",
      "third_party/git/t/t2014-checkout-switch.sh",
      "third_party/git/t/t2060-switch.sh",
      "third_party/git/t/t7201-co.sh",
    ],
  },
  {
    reason: "command:index",
    changed: [
      "modules/bit/cmd/bit/ls_files*.mbt",
      "modules/bit/cmd/bit/ls_tree.mbt",
      "modules/bit/cmd/bit/read_tree.mbt",
      "modules/bit/cmd/bit/update_index*.mbt",
      "modules/bit/cmd/bit/sparse_checkout*.mbt",
      "modules/bit/cmd/bit/check_attr.mbt",
      "modules/bit/cmd/bit/check_ignore*.mbt",
      "modules/bit_lib/src/gitattributes.mbt",
      "modules/bit_lib/src/tree_ops.mbt",
      "modules/bit_lib/src/index*.mbt",
    ],
    select: [
      "third_party/git/t/t300*.sh",
      "third_party/git/t/t310*.sh",
      "third_party/git/t/t613*.sh",
      "third_party/git/t/t7011-skip-worktree-reading.sh",
      "third_party/git/t/t7012-skip-worktree-writing.sh",
    ],
  },
  {
    reason: "command:branch",
    changed: [
      "modules/bit/cmd/bit/branch*.mbt",
      "modules/bit/cmd/bit/show_branches.mbt",
      "modules/bit_lib/src/branch*.mbt",
    ],
    select: [
      "third_party/git/t/t32*.sh",
      "third_party/git/t/t63*.sh",
      "third_party/git/t/t7419-submodule-set-branch.sh",
    ],
  },
  {
    reason: "command:diff",
    changed: [
      "modules/bit/cmd/bit/diff*.mbt",
      "modules/bit/cmd/bit/difftool.mbt",
    ],
    select: [
      "third_party/git/t/t40*.sh",
      "third_party/git/t/t6427-diff3-conflict-markers.sh",
    ],
  },
  {
    reason: "command:history",
    changed: [
      "modules/bit/cmd/bit/log*.mbt",
      "modules/bit/cmd/bit/rev_list*.mbt",
      "modules/bit/cmd/bit/merge_base.mbt",
      "modules/bit/cmd/bit/name_rev.mbt",
      "modules/bit/cmd/bit/describe.mbt",
      "modules/bit/cmd/bit/bisect*.mbt",
      "modules/bit/cmd/bit/bundle.mbt",
      "modules/bit/cmd/bit/fmt_merge_msg.mbt",
      "modules/bit/cmd/bit/last_modified.mbt",
      "modules/bit_lib/src/merge_base.mbt",
      "modules/bit_lib/src/last_modified.mbt",
      "modules/bit_lib/src/log*.mbt",
      "modules/bit_lib/src/revwalk*.mbt",
    ],
    select: [
      "third_party/git/t/t60*.sh",
      "third_party/git/t/t61*.sh",
      "third_party/git/t/t42*.sh",
      "third_party/git/t/t6120-describe.sh",
      "third_party/git/t/t6200-fmt-merge-msg.sh",
      "third_party/git/t/t8020-last-modified.sh",
    ],
  },
  {
    reason: "command:merge",
    changed: [
      "modules/bit/cmd/bit/merge*.mbt",
      "modules/bit/cmd/bit/cherry_pick*.mbt",
      "modules/bit/cmd/bit/rebase*.mbt",
      "modules/bit/cmd/bit/revert.mbt",
      "modules/bit/cmd/bit/history.mbt",
      "modules/bit_lib/src/cherry_pick.mbt",
      "modules/bit_lib/src/rebase*.mbt",
      "modules/bit_lib/src/merge*.mbt",
      "modules/bit_lib/src/history_*.mbt",
    ],
    select: [
      "third_party/git/t/t34*.sh",
      "third_party/git/t/t64*.sh",
      "third_party/git/t/t76*.sh",
      "third_party/git/t/t7402-submodule-rebase.sh",
    ],
  },
  {
    reason: "command:pack",
    changed: [
      "modules/bit/cmd/bit/pack*.mbt",
      "modules/bit/cmd/bit/index_pack.mbt",
      "modules/bit/cmd/bit/unpack_objects.mbt",
      "modules/bit/cmd/bit/verify_pack.mbt",
      "modules/bit/cmd/bit/multi_pack_index*.mbt",
      "modules/bit/cmd/bit/commit_graph*.mbt",
      "modules/bit/cmd/bit/repack*.mbt",
      "modules/bit/cmd/bit/gc.mbt",
      "modules/bit/cmd/bit/maintenance.mbt",
      "modules/bit/cmd/bit/prune*.mbt",
      "modules/bit/cmd/bit/fsck*.mbt",
    ],
    select: [
      "third_party/git/t/t53*.sh",
      "third_party/git/t/t1450-fsck.sh",
      "third_party/git/t/t6113-rev-list-bitmap-filters.sh",
      "third_party/git/t/t6114-keep-packs.sh",
      "third_party/git/t/t7700-repack.sh",
    ],
  },
  {
    reason: "command:transport",
    changed: [
      "modules/bit/cmd/bit/fetch*.mbt",
      "modules/bit/cmd/bit/pull.mbt",
      "modules/bit/cmd/bit/push.mbt",
      "modules/bit/cmd/bit/clone*.mbt",
      "modules/bit/cmd/bit/remote*.mbt",
      "modules/bit/cmd/bit/receive_pack.mbt",
      "modules/bit/cmd/bit/upload_pack.mbt",
      "modules/bit/cmd/bit/fetch_pack.mbt",
      "modules/bit/cmd/bit/send_pack.mbt",
      "modules/bit/cmd/bit/http_fetch.mbt",
      "modules/bit/cmd/bit/http_serve_*.mbt",
      "modules/bit/cmd/bit/fetch_serve_*.mbt",
      "modules/bit/cmd/bit/ls_remote.mbt",
      "modules/bit/cmd/bit/serve.mbt",
      "modules/bit_lib/src/remote*.mbt",
      "modules/bit_lib/src/upload_pack*.mbt",
      "modules/bit_lib/src/receive_pack*.mbt",
      "modules/bit_lib/src/smart_http*.mbt",
    ],
    select: [
      "third_party/git/t/t55*.sh",
      "third_party/git/t/t57*.sh",
      "third_party/git/t/t5750-bundle-uri-parse.sh",
    ],
  },
  {
    reason: "command:porcelain",
    changed: [
      "modules/bit/cmd/bit/add*.mbt",
      "modules/bit/cmd/bit/commit*.mbt",
      "modules/bit/cmd/bit/reset*.mbt",
      "modules/bit/cmd/bit/status*.mbt",
      "modules/bit/cmd/bit/show*.mbt",
      "modules/bit/cmd/bit/rm*.mbt",
      "modules/bit/cmd/bit/mv.mbt",
      "modules/bit/cmd/bit/stash.mbt",
      "modules/bit/cmd/bit/clean.mbt",
      "modules/bit_lib/src/reset.mbt",
      "modules/bit_lib/src/stash*.mbt",
      "modules/bit_lib/src/status*.mbt",
      "modules/bit_lib/src/add*.mbt",
      "modules/bit_lib/src/commit*.mbt",
    ],
    select: [
      "third_party/git/t/t39*.sh",
      "third_party/git/t/t7001-mv.sh",
      "third_party/git/t/t7002-mv-sparse-checkout.sh",
      "third_party/git/t/t7007-show.sh",
      "third_party/git/t/t706*.sh",
      "third_party/git/t/t710*.sh",
      "third_party/git/t/t711*.sh",
      "third_party/git/t/t730*.sh",
      "third_party/git/t/t750*.sh",
      "third_party/git/t/t751*.sh",
      "third_party/git/t/t752*.sh",
    ],
  },
  {
    reason: "command:tag",
    changed: [
      "modules/bit/cmd/bit/mktag_cmd.mbt",
      "modules/bit/cmd/bit/tag*.mbt",
      "modules/bit/cmd/bit/verify_tag.mbt",
      "modules/bit_lib/src/tag*.mbt",
    ],
    select: [
      "third_party/git/t/t7004-tag.sh",
      "third_party/git/t/t7030-verify-tag.sh",
      "third_party/git/t/t7031-verify-tag-signed-ssh.sh",
    ],
  },
  {
    reason: "command:submodule",
    changed: [
      "modules/bit/cmd/bit/submodule*.mbt",
      "modules/bit/cmd/bit/worktree*.mbt",
      "modules/bit_lib/src/worktree*.mbt",
      "modules/bit_lib/src/submodule*.mbt",
    ],
    select: [
      "third_party/git/t/t24*.sh",
      "third_party/git/t/t74*.sh",
      "third_party/git/t/t6437-submodule-merge.sh",
      "third_party/git/t/t6438-submodule-directory-file-conflicts.sh",
    ],
  },
  {
    reason: "command:blame",
    changed: [
      "modules/bit/cmd/bit/blame.mbt",
      "modules/bit/cmd/bit/annotate.mbt",
      "modules/bit/cmd/bit/shortlog.mbt",
    ],
    select: ["third_party/git/t/t80*.sh"],
  },
  {
    reason: "command:patch",
    changed: [
      "modules/bit/cmd/bit/format_patch.mbt",
      "modules/bit/cmd/bit/am.mbt",
      "modules/bit/cmd/bit/apply.mbt",
      "modules/bit/cmd/bit/mailsplit.mbt",
      "modules/bit/cmd/bit/mailinfo.mbt",
      "modules/bit/cmd/bit/quiltimport.mbt",
      "modules/bit/cmd/bit/patch_id.mbt",
      "modules/bit/cmd/bit/range_diff.mbt",
    ],
    select: [
      "third_party/git/t/t41*.sh",
      "third_party/git/t/t51*.sh",
      "third_party/git/t/t3206-range-diff.sh",
    ],
  },
  {
    reason: "command:grep",
    changed: ["modules/bit/cmd/bit/grep.mbt"],
    select: ["third_party/git/t/t781*.sh"],
  },
  {
    reason: "command:notes",
    changed: ["modules/bit/cmd/bit/notes.mbt"],
    select: ["third_party/git/t/t33*.sh"],
  },
];

function escapeRegex(value) {
  return value.replace(/[.+^${}()|[\]\\]/g, "\\$&");
}

// Escape character-by-character so glob tokens are substituted before any
// regex escaping can mangle them. (The previous implementation escaped the
// expansion of `**` into `\\.*` -- "zero or more dots" -- which silently
// broke every `**` rule.)
function compileGlob(glob) {
  const normalized = glob.replaceAll("\\", "/");
  let out = "";
  for (let i = 0; i < normalized.length; i++) {
    if (normalized.startsWith("**", i)) {
      out += ".*";
      i += 1;
    } else if (normalized[i] === "*") {
      out += "[^/]*";
    } else if (normalized[i] === "?") {
      out += "[^/]";
    } else {
      out += escapeRegex(normalized[i]);
    }
  }
  return new RegExp(`^${out}$`);
}

function compileRule(rule) {
  return {
    ...rule,
    changedPatterns: rule.changed.map(compileGlob),
    selectPatterns: rule.select.map(compileGlob),
  };
}

function quoteTomlString(value) {
  return JSON.stringify(value);
}

function renderTomlArray(values) {
  return `[${values.map(quoteTomlString).join(", ")}]`;
}

export function renderAffectedRulesToml(rules) {
  return `${rules.map((rule) => [
    "[[rules]]",
    `changed = ${renderTomlArray(rule.changed)}`,
    `select = ${renderTomlArray(rule.select)}`,
    `reason = ${quoteTomlString(rule.reason)}`,
  ].join("\n")).join("\n\n")}\n`;
}

export function selectSuitesForChanges(changedFiles, suites, rules) {
  const compiledRules = rules.map(compileRule);
  const selected = new Set();

  for (const file of changedFiles.map((value) => value.replaceAll("\\", "/"))) {
    const matchingRules = compiledRules.filter((rule) =>
      rule.changedPatterns.some((pattern) => pattern.test(file)),
    );
    if (matchingRules.length === 0) continue;

    for (const suite of suites) {
      const normalizedSuite = suite.replaceAll("\\", "/");
      if (matchingRules.some((rule) =>
        rule.selectPatterns.some((pattern) => pattern.test(normalizedSuite))
      )) {
        selected.add(suite);
      }
    }
  }

  return suites.filter((suite) => selected.has(suite));
}

/// True when `file` matches at least one rule's `changed` globs.
export function fileHasRule(file, rules) {
  const normalized = file.replaceAll("\\", "/");
  return rules.some((rule) =>
    rule.changed.some((glob) => compileGlob(glob).test(normalized)),
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.stdout.write(renderAffectedRulesToml(GIT_COMPAT_AFFECTED_RULES));
}
