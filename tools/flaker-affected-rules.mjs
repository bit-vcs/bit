import { pathToFileURL } from "node:url";

export const GIT_COMPAT_AFFECTED_RULES = [
  {
    reason: "infrastructure",
    changed: [
      "moon.mod.json",
      "src/top.mbt",
      "src/cmd/bit/main*.mbt",
      "src/cmd/bit/helpers*.mbt",
      "src/cmd/bit/fallback*.mbt",
      "tools/git-shim/**",
      "tools/run-git-test.sh",
      "tools/apply-git-test-patches.sh",
      "tools/select-git-tests.sh",
      "tools/flaker-run-git-compat-tests.mjs",
    ],
    select: ["third_party/git/t/*.sh"],
  },
  {
    reason: "command:setup",
    changed: [
      "src/cmd/bit/init*.mbt",
      "src/cmd/bit/config*.mbt",
      "src/cmd/bit/gitconfig*.mbt",
      "src/cmd/bit/show_ref.mbt",
      "src/cmd/bit/symbolic_ref.mbt",
      "src/cmd/bit/rev_parse*.mbt",
      "src/cmd/bit/hash_object*.mbt",
      "src/cmd/bit/cat_file*.mbt",
      "src/object/**",
      "src/hash/**",
      "src/refs/**",
      "src/repo_ops/revparse_ops.mbt",
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
    reason: "command:checkout",
    changed: [
      "src/cmd/bit/checkout*.mbt",
      "src/cmd/bit/switch*.mbt",
      "src/cmd/bit/restore*.mbt",
      "src/cmd/bit/checkout_index.mbt",
      "src/lib/checkout*.mbt",
      "src/lib/path.mbt",
      "src/worktree/**",
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
      "src/cmd/bit/ls_files*.mbt",
      "src/cmd/bit/ls_tree.mbt",
      "src/cmd/bit/read_tree.mbt",
      "src/cmd/bit/update_index*.mbt",
      "src/cmd/bit/sparse_checkout*.mbt",
      "src/cmd/bit/check_attr.mbt",
      "src/cmd/bit/check_ignore.mbt",
      "src/lib/gitattributes.mbt",
      "src/lib/tree_ops.mbt",
      "src/worktree/**",
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
      "src/cmd/bit/branch*.mbt",
      "src/cmd/bit/show_branches.mbt",
      "src/cmd/bit/for_each_ref.mbt",
      "src/cmd/bit/show_ref.mbt",
      "src/refs/**",
    ],
    select: [
      "third_party/git/t/t320*.sh",
      "third_party/git/t/t630*.sh",
    ],
  },
  {
    reason: "command:diff",
    changed: [
      "src/cmd/bit/diff*.mbt",
      "src/cmd/bit/difftool.mbt",
      "src/diff/**",
      "src/diff_core/**",
    ],
    select: [
      "third_party/git/t/t400*.sh",
      "third_party/git/t/t6427-diff3-conflict-markers.sh",
    ],
  },
  {
    reason: "command:history",
    changed: [
      "src/cmd/bit/log*.mbt",
      "src/cmd/bit/rev_list*.mbt",
      "src/cmd/bit/merge_base.mbt",
      "src/cmd/bit/name_rev.mbt",
      "src/cmd/bit/describe.mbt",
      "src/cmd/bit/bisect*.mbt",
      "src/cmd/bit/bundle.mbt",
      "src/cmd/bit/fmt_merge_msg.mbt",
      "src/lib/merge_base.mbt",
      "src/repo/**",
      "src/repo_ops/**",
    ],
    select: [
      "third_party/git/t/t60*.sh",
      "third_party/git/t/t610*.sh",
      "third_party/git/t/t611*.sh",
      "third_party/git/t/t6120-describe.sh",
      "third_party/git/t/t6200-fmt-merge-msg.sh",
    ],
  },
  {
    reason: "command:merge",
    changed: [
      "src/cmd/bit/merge*.mbt",
      "src/cmd/bit/cherry_pick*.mbt",
      "src/cmd/bit/rebase*.mbt",
      "src/cmd/bit/revert.mbt",
      "src/lib/cherry_pick.mbt",
      "src/lib/rebase.mbt",
      "src/lib/merge*.mbt",
    ],
    select: [
      "third_party/git/t/t640*.sh",
      "third_party/git/t/t641*.sh",
      "third_party/git/t/t642*.sh",
      "third_party/git/t/t643*.sh",
      "third_party/git/t/t7402-submodule-rebase.sh",
      "third_party/git/t/t760*.sh",
      "third_party/git/t/t761*.sh",
    ],
  },
  {
    reason: "command:pack",
    changed: [
      "src/cmd/bit/pack*.mbt",
      "src/cmd/bit/index_pack.mbt",
      "src/cmd/bit/unpack_objects.mbt",
      "src/cmd/bit/verify_pack.mbt",
      "src/cmd/bit/multi_pack_index*.mbt",
      "src/cmd/bit/commit_graph*.mbt",
      "src/pack/**",
      "src/pack_ops/**",
    ],
    select: [
      "third_party/git/t/t530*.sh",
      "third_party/git/t/t531*.sh",
      "third_party/git/t/t532*.sh",
      "third_party/git/t/t533*.sh",
      "third_party/git/t/t5351-unpack-large-objects.sh",
      "third_party/git/t/t6113-rev-list-bitmap-filters.sh",
      "third_party/git/t/t6114-keep-packs.sh",
    ],
  },
  {
    reason: "command:transport",
    changed: [
      "src/cmd/bit/fetch*.mbt",
      "src/cmd/bit/pull.mbt",
      "src/cmd/bit/push.mbt",
      "src/cmd/bit/clone*.mbt",
      "src/cmd/bit/remote*.mbt",
      "src/cmd/bit/receive_pack.mbt",
      "src/cmd/bit/upload_pack.mbt",
      "src/cmd/bit/fetch_pack.mbt",
      "src/cmd/bit/send_pack.mbt",
      "src/cmd/bit/http_fetch.mbt",
      "src/cmd/bit/http_serve_*.mbt",
      "src/cmd/bit/fetch_serve_*.mbt",
      "src/lib/remote*.mbt",
      "src/protocol/**",
      "src/io/http_client.mbt",
      "src/io/native/http_client_native.mbt",
      "src/io/native/upload_pack*.mbt",
      "src/io/native/remote.mbt",
      "src/remote/**",
    ],
    select: [
      "third_party/git/t/t550*.sh",
      "third_party/git/t/t551*.sh",
      "third_party/git/t/t552*.sh",
      "third_party/git/t/t553*.sh",
      "third_party/git/t/t570*.sh",
      "third_party/git/t/t5710-promisor-remote-capability.sh",
      "third_party/git/t/t573*.sh",
      "third_party/git/t/t5750-bundle-uri-parse.sh",
    ],
  },
  {
    reason: "command:porcelain",
    changed: [
      "src/cmd/bit/add*.mbt",
      "src/cmd/bit/commit*.mbt",
      "src/cmd/bit/reset*.mbt",
      "src/cmd/bit/status*.mbt",
      "src/cmd/bit/show*.mbt",
      "src/cmd/bit/rm*.mbt",
      "src/cmd/bit/mv.mbt",
      "src/cmd/bit/tag*.mbt",
      "src/cmd/bit/stash.mbt",
      "src/cmd/bit/clean.mbt",
      "src/lib/reset.mbt",
    ],
    select: [
      "third_party/git/t/t7001-mv.sh",
      "third_party/git/t/t7002-mv-sparse-checkout.sh",
      "third_party/git/t/t7004-tag.sh",
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
    reason: "command:submodule",
    changed: [
      "src/cmd/bit/submodule*.mbt",
      "src/cmd/bit/worktree*.mbt",
      "src/cmd/bit/sparse_checkout*.mbt",
      "src/x/subdir/**",
    ],
    select: [
      "third_party/git/t/t6437-submodule-merge.sh",
      "third_party/git/t/t6438-submodule-directory-file-conflicts.sh",
      "third_party/git/t/t740*.sh",
      "third_party/git/t/t741*.sh",
      "third_party/git/t/t742*.sh",
      "third_party/git/t/t7450-bad-git-dotfiles.sh",
    ],
  },
];

function escapeRegex(value) {
  return value.replace(/[.+^${}()|[\]\\]/g, "\\$&");
}

function compileGlob(glob) {
  const escaped = glob
    .replaceAll("\\", "/")
    .replaceAll("**", "\u0000")
    .replaceAll("*", "[^/]*")
    .replaceAll("?", "[^/]")
    .replaceAll("\u0000", ".*");
  return new RegExp(`^${escapeRegex(escaped).replace(/\\\[\\\^\/\\\]\\\*/g, "[^/]*").replace(/\\\[\\\^\/\\\]/g, "[^/]")}$`);
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

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.stdout.write(renderAffectedRulesToml(GIT_COMPAT_AFFECTED_RULES));
}
