///|
test "parse_manifest: full entry, defaults and normalization" {
  let m = @home.parse_manifest(
    #|[[repo]]
    #|name = "storefront"
    #|path = "~/repos/acme/storefront"
    #|url = "git@github.com:acme/storefront.git"
    #|description = "Next.js app"
    #|branch = "main"
    #|subdir = "/apps/web/"
    #|notes = "Read its AGENTS.md before changing it."
    #|
    #|[[repo]]
    #|path = "../payments-api.git"
    #|
    ,
  )
  assert_eq(m.repos.length(), 2)
  let s = m.repos[0]
  assert_eq(s.name, "storefront")
  assert_eq(s.subdir, Some("apps/web"))
  assert_eq(s.branch, Some("main"))
  // name defaults to the path basename without `.git`
  assert_eq(m.repos[1].name, "payments-api")
  assert_eq(m.repos[1].url, None)
  assert_eq(m.find("payments-api").map(r => r.path), Some("../payments-api.git"))
  assert_eq(@home.parse_manifest("").repos.length(), 0)
}

///|
test "parse_manifest: rejects invalid manifests" {
  let bad = [
    "[[repo]]\nname = \"x\"\n", // missing path
    "[[repo]]\npath = \"a\"\nsubdirs = \"x\"\n", // unknown key
    "[repos]\n", // unknown top-level key
    "[[repo]]\npath = \"a\"\n[[repo]]\npath = \"b/a\"\n", // duplicate name
    "[[repo]]\nname = \"../x\"\npath = \"a\"\n", // invalid name
    "[[repo]]\npath = \"a\"\nsubdir = \"../etc\"\n", // traversal
    "[[repo]]\npath = \"a\"\nbranch = \"--upload-pack=x\"\n",
    "[[repo]]\npath = \"a\"\nurl = \"--upload-pack=x\"\n",
    "[[repo]]\npath = 1\n",
    "not toml = = =",
  ]
  for content in bad {
    let rejected = try {
      ignore(@home.parse_manifest(content))
      false
    } catch {
      _ => true
    }
    if !rejected {
      fail("expected rejection: \{content}")
    }
  }
}

///|
test "resolve_repo_path: home, absolute and home-repo-relative" {
  let r = fn(p) { @home.resolve_repo_path(p, home="/h", home_repo_root="/h/home") }
  assert_eq(r("~/repos/a"), "/h/repos/a")
  assert_eq(r("~"), "/h")
  assert_eq(r("/srv/a"), "/srv/a")
  assert_eq(r("../a"), "/h/home/../a")
  assert_eq(r("./a"), "/h/home/a")
}

///|
test "repo_toml_block round-trips through parse_manifest" {
  let repo : @home.HomeRepo = {
    name: "api",
    path: "~/repos/api",
    url: Some("https://example.com/a \"b\".git"),
    description: Some("API\tserver"),
    branch: None,
    subdir: Some("svc"),
    notes: None,
  }
  let m = @home.parse_manifest(@home.manifest_template + "\n" + @home.repo_toml_block(repo))
  assert_eq(m.repos, [repo])
}

///|
test "render and update AGENTS.md keep text outside the managed block" {
  let m = @home.parse_manifest(
    #|[[repo]]
    #|name = "web"
    #|path = "~/repos/web"
    #|url = "git@example.com:web.git"
    #|subdir = "apps/web"
    #|description = "frontend"
    ,
  )
  let block = @home.render_agents_block(m)
  assert_true(block.contains("- **web** (frontend): `~/repos/web`. Clone from `git@example.com:web.git` if missing. Only `apps/web/` is checked out (sparse)."))
  let original = "# Notes\n\nkeep me\n"
  let first = @home.update_agents_md(original, block)
  assert_true(first.has_prefix(original))
  assert_true(first.contains("## Other Repos"))
  // Re-rendering replaces the block in place and is idempotent.
  let edited = first + "\ntrailer\n"
  let again = @home.update_agents_md(edited, block)
  assert_eq(again, edited)
  let empty_block = @home.render_agents_block({ repos: [] })
  let replaced = @home.update_agents_md(edited, empty_block)
  assert_true(replaced.has_prefix(original))
  assert_true(replaced.has_suffix("\ntrailer\n"))
  assert_false(replaced.contains("**web**"))
}

///|
test "feature names" {
  for ok in ["feat-x", "user/feat_1", "v1.2"] {
    assert_true(@home.is_valid_feature_name(ok))
  }
  for bad in ["", "-x", "a/../b", "../x", "a//b", "/x", "x/", ".hidden", "a b", "x.lock"] {
    if @home.is_valid_feature_name(bad) {
      fail("expected invalid feature name '\{bad}'")
    }
  }
  assert_eq(@home.worktree_path("/r/web", "f"), "/r/web/.worktrees/f")
}

///|
test "parse_porcelain_status, upstream_from_config and describe_status" {
  let s = @home.parse_porcelain_status(
    #|## main...origin/main [ahead 2]
    #| M file.txt
    #|?? new.txt
    ,
  )
  assert_eq(s.branch, Some("main"))
  assert_eq(s.changes, 2)
  assert_eq(@home.parse_porcelain_status("## main\n").branch, Some("main"))
  assert_eq(@home.parse_porcelain_status("## No commits yet on master\n").branch, Some("master"))
  assert_eq(@home.parse_porcelain_status("## HEAD (no branch)\n").branch, None)
  assert_eq(
    @home.upstream_from_config("origin\n", "refs/heads/main\n"),
    Some(("origin/main", "refs/remotes/origin/main")),
  )
  assert_eq(@home.upstream_from_config(".", "refs/heads/dev"), Some(("dev", "refs/heads/dev")))
  assert_eq(@home.upstream_from_config("", "refs/heads/main"), None)
  let full : @home.RepoStatus = { ..s, upstream: Some("origin/main"), ahead: 2, behind: 1 }
  assert_eq(@home.describe_status(full), "main, ahead 2, behind 1 vs origin/main, 2 changed")
  let clean = @home.parse_porcelain_status("## HEAD (no branch)\n")
  assert_eq(@home.describe_status(clean), "(detached), no upstream, clean")
}
