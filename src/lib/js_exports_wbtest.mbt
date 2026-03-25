///| JS export bridge tests for `mizchi/bit/lib`.

///|
fn[T] js_exports_unwrap_ok(label : String, result : Result[T, String]) -> T {
  match result {
    Ok(value) => value
    Err(error) => abort("\{label}: \{error}")
  }
}

///|
fn js_exports_parse_loose_header(raw : Bytes) -> (String, Int) {
  let type_buf = StringBuilder::new()
  let mut i = 0
  while i < raw.length() && raw[i] != b' ' {
    type_buf.write_char(raw[i].to_int().unsafe_to_char())
    i += 1
  }
  i += 1
  while i < raw.length() && raw[i] != b'\x00' {
    i += 1
  }
  i += 1
  (type_buf.to_string(), i)
}

///|
test "js exports: memory host supports local git flow" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "hostWriteString",
    js_host_write_string(host_id, "/repo/hello.txt", "hello\n"),
  )

  let before_add = js_exports_unwrap_ok(
    "status before add",
    js_status(host_id, "/repo"),
  )
  assert_eq(before_add.untracked, ["hello.txt"])
  assert_eq(before_add.staged_added, [])

  js_exports_unwrap_ok("add", js_add_paths(host_id, "/repo", ["hello.txt"]))

  let after_add = js_exports_unwrap_ok(
    "status after add",
    js_status(host_id, "/repo"),
  )
  assert_eq(after_add.staged_added, ["hello.txt"])
  assert_eq(after_add.untracked, [])

  let commit_id = js_exports_unwrap_ok(
    "commit",
    js_commit(
      host_id, "/repo", "initial commit", "Tester <tester@example.com>", 1700000000,
    ),
  )
  assert_true(commit_id.length() == 40)

  js_exports_unwrap_ok("checkoutB", js_checkout_b(host_id, "/repo", "feature"))

  let branches = js_exports_unwrap_ok(
    "branchList",
    js_branch_list(host_id, "/repo"),
  )
  let mut saw_feature = false
  let mut saw_main = false
  for branch in branches {
    if branch.name == "feature" {
      saw_feature = true
      assert_true(branch.is_current)
    }
    if branch.name == "main" {
      saw_main = true
    }
  }
  assert_true(saw_feature)
  assert_true(saw_main)

  let log_entries = js_exports_unwrap_ok("log", js_log(host_id, "/repo", 10))
  assert_eq(log_entries.length(), 1)
  assert_eq(log_entries[0].message, "initial commit")
  assert_eq(log_entries[0].author, "Tester <tester@example.com>")

  let head_text = js_exports_unwrap_ok(
    "hostReadString",
    js_host_read_string(host_id, "/repo/.git/HEAD"),
  )
  assert_eq(head_text, "ref: refs/heads/feature\n")

  js_destroy_host(host_id)
}

///|
test "js exports: signed commit stores gpgsig header" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "hostWriteString",
    js_host_write_string(host_id, "/repo/hello.txt", "hello\n"),
  )
  js_exports_unwrap_ok("add", js_add_paths(host_id, "/repo", ["hello.txt"]))

  let payload = js_exports_unwrap_ok(
    "buildCommitPayload",
    js_build_commit_payload(
      host_id, "/repo", "signed commit", "Signer <signer@example.com>", 1700000000,
    ),
  )
  assert_true(payload.contains("tree "))
  assert_false(payload.contains("gpgsig "))

  let commit_id = js_exports_unwrap_ok(
    "commitSigned",
    js_commit_signed(
      host_id, "/repo", "signed commit", "Signer <signer@example.com>", 1700000000,
      "-----BEGIN TEST SIGNATURE-----\nabc123\n-----END TEST SIGNATURE-----\n",
    ),
  )

  let fs = js_make_host_fs(host_id)
  let object_dir = String::unsafe_substring(commit_id, start=0, end=2)
  let object_file = String::unsafe_substring(
    commit_id,
    start=2,
    end=commit_id.length(),
  )
  let object_path = join_path(
    join_path("/repo/.git/objects", object_dir),
    object_file,
  )
  let compressed = fs.read_file(object_path)
  let raw = @zlib.zlib_decompress(compressed)
  let (obj_type, content_start) = js_exports_parse_loose_header(raw)
  assert_eq(obj_type, "commit")
  let content = Bytes::from_array(
    FixedArray::makei(raw.length() - content_start, fn(i) {
      raw[content_start + i]
    }),
  )
  let text = @utf8.decode_lossy(content[:])
  assert_true(
    text.contains(
      "gpgsig -----BEGIN TEST SIGNATURE-----\n abc123\n -----END TEST SIGNATURE-----\n",
    ),
  )
  assert_true(text.contains("\n\nsigned commit\n"))

  js_destroy_host(host_id)
}

///|
test "js exports: merge merges another branch by refname" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write base",
    js_host_write_string(
      host_id, "/repo/file.txt", "line1\nline2\nline3\nline4\n",
    ),
  )
  js_exports_unwrap_ok("add base", js_add_paths(host_id, "/repo", ["file.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit base",
      js_commit(
        host_id, "/repo", "base", "Tester <tester@example.com>", 1700000000,
      ),
    ),
  )

  js_exports_unwrap_ok("checkoutB", js_checkout_b(host_id, "/repo", "feature"))
  js_exports_unwrap_ok(
    "write feature",
    js_host_write_string(
      host_id, "/repo/file.txt", "line1\nfeature\nline3\nline4\n",
    ),
  )
  js_exports_unwrap_ok(
    "add feature",
    js_add_paths(host_id, "/repo", ["file.txt"]),
  )
  ignore(
    js_exports_unwrap_ok(
      "commit feature",
      js_commit(
        host_id, "/repo", "feature commit", "Tester <tester@example.com>", 1700000001,
      ),
    ),
  )

  js_exports_unwrap_ok("checkout main", js_checkout(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write main",
    js_host_write_string(
      host_id, "/repo/file.txt", "line1\nline2\nline3\nmain\n",
    ),
  )
  js_exports_unwrap_ok("add main", js_add_paths(host_id, "/repo", ["file.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit main",
      js_commit(
        host_id, "/repo", "main commit", "Tester <tester@example.com>", 1700000002,
      ),
    ),
  )

  let merge_result = js_exports_unwrap_ok(
    "merge",
    js_merge(
      host_id, "/repo", "feature", "merge feature", "Tester <tester@example.com>",
      1700000003,
    ),
  )
  assert_eq(merge_result.status, "merged")
  assert_true(merge_result.commit_id.length() == 40)
  assert_eq(merge_result.conflicts, [])
  assert_eq(
    js_exports_unwrap_ok(
      "merged file",
      js_host_read_string(host_id, "/repo/file.txt"),
    ),
    "line1\nfeature\nline3\nmain\n",
  )

  let log_entries = js_exports_unwrap_ok("log", js_log(host_id, "/repo", 3))
  assert_eq(log_entries[0].message, "merge feature")

  js_destroy_host(host_id)
}

///|
test "js exports: rebase start rebases current branch onto upstream refname" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write a",
    js_host_write_string(host_id, "/repo/a.txt", "A\n"),
  )
  js_exports_unwrap_ok("add a", js_add_paths(host_id, "/repo", ["a.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit a",
      js_commit(
        host_id, "/repo", "A", "Tester <tester@example.com>", 1700000000,
      ),
    ),
  )

  js_exports_unwrap_ok(
    "checkoutB topic",
    js_checkout_b(host_id, "/repo", "topic"),
  )
  js_exports_unwrap_ok(
    "write d",
    js_host_write_string(host_id, "/repo/d.txt", "D\n"),
  )
  js_exports_unwrap_ok("add d", js_add_paths(host_id, "/repo", ["d.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit d",
      js_commit(
        host_id, "/repo", "D", "Tester <tester@example.com>", 1700000001,
      ),
    ),
  )
  js_exports_unwrap_ok(
    "write e",
    js_host_write_string(host_id, "/repo/e.txt", "E\n"),
  )
  js_exports_unwrap_ok("add e", js_add_paths(host_id, "/repo", ["e.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit e",
      js_commit(
        host_id, "/repo", "E", "Tester <tester@example.com>", 1700000002,
      ),
    ),
  )

  js_exports_unwrap_ok("checkout main", js_checkout(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write b",
    js_host_write_string(host_id, "/repo/b.txt", "B\n"),
  )
  js_exports_unwrap_ok("add b", js_add_paths(host_id, "/repo", ["b.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit b",
      js_commit(
        host_id, "/repo", "B", "Tester <tester@example.com>", 1700000003,
      ),
    ),
  )
  js_exports_unwrap_ok(
    "write c",
    js_host_write_string(host_id, "/repo/c.txt", "C\n"),
  )
  js_exports_unwrap_ok("add c", js_add_paths(host_id, "/repo", ["c.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit c",
      js_commit(
        host_id, "/repo", "C", "Tester <tester@example.com>", 1700000004,
      ),
    ),
  )

  js_exports_unwrap_ok("checkout topic", js_checkout(host_id, "/repo", "topic"))
  let rebase_result = js_exports_unwrap_ok(
    "rebaseStart",
    js_rebase_start(host_id, "/repo", "main"),
  )
  assert_eq(rebase_result.status, "complete")
  assert_true(rebase_result.commit_id.length() == 40)
  assert_eq(rebase_result.conflicts, [])
  assert_eq(
    js_exports_unwrap_ok("read b", js_host_read_string(host_id, "/repo/b.txt")),
    "B\n",
  )
  assert_eq(
    js_exports_unwrap_ok("read c", js_host_read_string(host_id, "/repo/c.txt")),
    "C\n",
  )
  assert_eq(
    js_exports_unwrap_ok("read d", js_host_read_string(host_id, "/repo/d.txt")),
    "D\n",
  )
  assert_eq(
    js_exports_unwrap_ok("read e", js_host_read_string(host_id, "/repo/e.txt")),
    "E\n",
  )

  js_destroy_host(host_id)
}

///|
test "js exports: rev-parse tags reset restore remotes and branch rename" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write a",
    js_host_write_string(host_id, "/repo/a.txt", "one\n"),
  )
  js_exports_unwrap_ok("add a", js_add_paths(host_id, "/repo", ["a.txt"]))
  let first = js_exports_unwrap_ok(
    "commit first",
    js_commit(
      host_id, "/repo", "first", "Tester <tester@example.com>", 1700000100,
    ),
  )

  let head = js_exports_unwrap_ok(
    "revParse HEAD",
    js_rev_parse(host_id, "/repo", "HEAD"),
  )
  assert_eq(head, first)

  let refs = js_exports_unwrap_ok("showRef", js_show_ref(host_id, "/repo"))
  let mut saw_main = false
  for ref_info in refs {
    if ref_info.name == "refs/heads/main" {
      saw_main = true
      assert_eq(ref_info.id, first)
    }
  }
  assert_true(saw_main)

  js_exports_unwrap_ok(
    "write config",
    js_host_write_string(
      host_id, "/repo/.git/config", "[remote \"origin\"]\n\turl = https://example.com/repo.git\n",
    ),
  )
  assert_eq(
    js_exports_unwrap_ok("listRemotes", js_list_remotes(host_id, "/repo")),
    ["origin"],
  )
  assert_eq(
    js_exports_unwrap_ok(
      "getRemoteUrl",
      js_get_remote_url(host_id, "/repo", "origin"),
    ),
    "https://example.com/repo.git",
  )

  js_exports_unwrap_ok(
    "branchCreate",
    js_branch_create(host_id, "/repo", "topic"),
  )
  js_exports_unwrap_ok(
    "branchRename",
    js_branch_rename(
      host_id, "/repo", "topic", "renamed", false, "Tester", "tester@example.com",
      1700000101, "+0000",
    ),
  )
  let branches = js_exports_unwrap_ok(
    "branchList",
    js_branch_list(host_id, "/repo"),
  )
  let mut saw_renamed = false
  let mut saw_topic = false
  for branch in branches {
    if branch.name == "renamed" {
      saw_renamed = true
    }
    if branch.name == "topic" {
      saw_topic = true
    }
  }
  assert_true(saw_renamed)
  assert_false(saw_topic)

  js_exports_unwrap_ok(
    "tagCreateLightweight",
    js_tag_create_lightweight(host_id, "/repo", "v1", "HEAD"),
  )
  js_exports_unwrap_ok(
    "tagCreateAnnotated",
    js_tag_create_annotated(
      host_id, "/repo", "release", "HEAD", "release tag", "Tester <tester@example.com>",
      1700000102,
    ),
  )
  let tags = js_exports_unwrap_ok("tagList", js_tag_list(host_id, "/repo"))
  assert_true(tags.length() == 2)
  assert_true(tags.contains("release"))
  assert_true(tags.contains("v1"))
  assert_eq(
    js_exports_unwrap_ok(
      "revParse release^{commit}",
      js_rev_parse(host_id, "/repo", "release^{commit}"),
    ),
    first,
  )
  js_exports_unwrap_ok("tagDelete", js_tag_delete(host_id, "/repo", "v1"))
  assert_eq(
    js_exports_unwrap_ok("tagList after delete", js_tag_list(host_id, "/repo")),
    ["release"],
  )

  js_exports_unwrap_ok(
    "write worktree",
    js_host_write_string(host_id, "/repo/a.txt", "working\n"),
  )
  js_exports_unwrap_ok(
    "restorePaths",
    js_restore_paths(host_id, "/repo", ["a.txt"]),
  )
  assert_eq(
    js_exports_unwrap_ok(
      "read restored",
      js_host_read_string(host_id, "/repo/a.txt"),
    ),
    "one\n",
  )

  js_exports_unwrap_ok(
    "write second",
    js_host_write_string(host_id, "/repo/a.txt", "two\n"),
  )
  js_exports_unwrap_ok("add second", js_add_paths(host_id, "/repo", ["a.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit second",
      js_commit(
        host_id, "/repo", "second", "Tester <tester@example.com>", 1700000103,
      ),
    ),
  )
  assert_eq(
    js_exports_unwrap_ok("reset", js_reset(host_id, "/repo", "HEAD^", "hard")),
    first,
  )
  assert_eq(
    js_exports_unwrap_ok(
      "read reset",
      js_host_read_string(host_id, "/repo/a.txt"),
    ),
    "one\n",
  )
  assert_eq(
    js_exports_unwrap_ok(
      "revParse HEAD after reset",
      js_rev_parse(host_id, "/repo", "HEAD"),
    ),
    first,
  )

  js_destroy_host(host_id)
}

///|
async test "js exports: stash diff and cherry-pick" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init repo", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write base",
    js_host_write_string(host_id, "/repo/a.txt", "base\n"),
  )
  js_exports_unwrap_ok("add base", js_add_paths(host_id, "/repo", ["a.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit base",
      js_commit(
        host_id, "/repo", "base", "Tester <tester@example.com>", 1700000200,
      ),
    ),
  )

  js_exports_unwrap_ok(
    "write working",
    js_host_write_string(host_id, "/repo/a.txt", "working\n"),
  )
  let worktree_diff = js_exports_unwrap_ok(
    "diffWorktree",
    js_diff_worktree(host_id, "/repo"),
  )
  assert_true(worktree_diff.contains("diff --git a/a.txt b/a.txt"))
  let worktree_stat = js_exports_unwrap_ok(
    "diffWorktreeStat",
    js_diff_worktree_stat(host_id, "/repo"),
  )
  assert_true(worktree_stat[0].contains("a.txt"))

  let stash_id = js_exports_unwrap_ok(
    "stashPush",
    js_stash_push(
      host_id, "/repo", "save working", "Tester <tester@example.com>", 1700000201,
    ),
  )
  assert_true(stash_id.length() == 40)
  let stash_entries = js_exports_unwrap_ok(
    "stashList",
    js_stash_list(host_id, "/repo"),
  )
  assert_eq(stash_entries.length(), 1)
  assert_true(stash_entries[0].message.contains("save working"))
  assert_eq(
    js_exports_unwrap_ok(
      "read after stash",
      js_host_read_string(host_id, "/repo/a.txt"),
    ),
    "base\n",
  )

  js_exports_unwrap_ok("stashApply", js_stash_apply(host_id, "/repo", 0, false))
  assert_eq(
    js_exports_unwrap_ok(
      "read after apply",
      js_host_read_string(host_id, "/repo/a.txt"),
    ),
    "working\n",
  )
  js_exports_unwrap_ok("add working", js_add_paths(host_id, "/repo", ["a.txt"]))
  let index_diff = js_exports_unwrap_ok(
    "diffIndex",
    js_diff_index(host_id, "/repo"),
  )
  assert_true(index_diff.contains("diff --git a/a.txt b/a.txt"))
  let index_stat = js_exports_unwrap_ok(
    "diffIndexStat",
    js_diff_index_stat(host_id, "/repo"),
  )
  assert_true(index_stat[index_stat.length() - 1].contains("1 file(s) changed"))
  js_exports_unwrap_ok("stashDrop", js_stash_drop(host_id, "/repo", 0))
  assert_eq(
    js_exports_unwrap_ok(
      "stashList after drop",
      js_stash_list(host_id, "/repo"),
    ).length(),
    0,
  )

  js_exports_unwrap_ok("init pick", js_git_init(host_id, "/pick", "main"))
  js_exports_unwrap_ok(
    "write pick base",
    js_host_write_string(host_id, "/pick/base.txt", "base\n"),
  )
  js_exports_unwrap_ok(
    "add pick base",
    js_add_paths(host_id, "/pick", ["base.txt"]),
  )
  ignore(
    js_exports_unwrap_ok(
      "commit pick base",
      js_commit(
        host_id, "/pick", "base", "Tester <tester@example.com>", 1700000300,
      ),
    ),
  )
  js_exports_unwrap_ok(
    "checkoutB feature",
    js_checkout_b(host_id, "/pick", "feature"),
  )
  js_exports_unwrap_ok(
    "write side",
    js_host_write_string(host_id, "/pick/side.txt", "side\n"),
  )
  js_exports_unwrap_ok("add side", js_add_paths(host_id, "/pick", ["side.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit side",
      js_commit(
        host_id, "/pick", "side", "Tester <tester@example.com>", 1700000301,
      ),
    ),
  )
  js_exports_unwrap_ok("checkout main", js_checkout(host_id, "/pick", "main"))
  let cherry_pick_result = js_exports_unwrap_ok(
    "cherryPick",
    js_cherry_pick(
      host_id, "/pick", "feature", "Tester <tester@example.com>", 1700000302, false,
      "", "",
    ),
  )
  assert_eq(cherry_pick_result.status, "success")
  assert_true(cherry_pick_result.commit_id.length() == 40)
  assert_eq(
    js_exports_unwrap_ok(
      "read cherry-picked",
      js_host_read_string(host_id, "/pick/side.txt"),
    ),
    "side\n",
  )

  js_destroy_host(host_id)
}

///|
async test "js exports: status text amend switch branch and remote verbose" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init", js_git_init(host_id, "/repo", "main"))
  js_exports_unwrap_ok(
    "write a",
    js_host_write_string(host_id, "/repo/a.txt", "one\n"),
  )
  let initial_status_text = js_exports_unwrap_ok(
    "statusText initial",
    js_status_text(host_id, "/repo"),
  )
  assert_true(initial_status_text.contains("On branch main"))
  assert_true(initial_status_text.contains("No commits yet"))

  js_exports_unwrap_ok("add a", js_add_paths(host_id, "/repo", ["a.txt"]))
  let staged_status_text = js_exports_unwrap_ok(
    "statusText staged",
    js_status_text(host_id, "/repo"),
  )
  assert_true(staged_status_text.contains("Changes to be committed"))
  ignore(
    js_exports_unwrap_ok(
      "commit",
      js_commit(
        host_id, "/repo", "first", "Tester <tester@example.com>", 1700000400,
      ),
    ),
  )

  js_exports_unwrap_ok(
    "switchBranch feature",
    js_switch_branch(host_id, "/repo", "feature", true, true),
  )
  let feature_head = js_exports_unwrap_ok(
    "head feature",
    js_host_read_string(host_id, "/repo/.git/HEAD"),
  )
  assert_eq(feature_head, "ref: refs/heads/feature\n")

  js_exports_unwrap_ok(
    "write feature",
    js_host_write_string(host_id, "/repo/a.txt", "feature\n"),
  )
  js_exports_unwrap_ok("add feature", js_add_paths(host_id, "/repo", ["a.txt"]))
  ignore(
    js_exports_unwrap_ok(
      "commit feature",
      js_commit(
        host_id, "/repo", "feature", "Tester <tester@example.com>", 1700000401,
      ),
    ),
  )
  let original_head = js_exports_unwrap_ok(
    "head before amend",
    js_rev_parse(host_id, "/repo", "HEAD"),
  )
  let amended = js_exports_unwrap_ok(
    "commitAmend",
    js_commit_amend(
      host_id, "/repo", "feature amended", "Tester <tester@example.com>", 1700000402,
      "Tester <tester@example.com>", 1700000402, "+0000", "UTF-8", "", "",
    ),
  )
  assert_true(amended.length() == 40)
  assert_true(amended != original_head)
  let log_entries = js_exports_unwrap_ok("log", js_log(host_id, "/repo", 2))
  assert_eq(log_entries[0].message, "feature amended")

  js_exports_unwrap_ok(
    "switchBranch main",
    js_switch_branch(host_id, "/repo", "main", false, true),
  )
  assert_eq(
    js_exports_unwrap_ok(
      "read main file",
      js_host_read_string(host_id, "/repo/a.txt"),
    ),
    "one\n",
  )

  js_exports_unwrap_ok(
    "write config",
    js_host_write_string(
      host_id, "/repo/.git/config", "[remote \"origin\"]\n\turl = https://example.com/fetch.git\n\tpushurl = https://example.com/push.git\n",
    ),
  )
  let remotes = js_exports_unwrap_ok(
    "listRemotesVerbose",
    js_list_remotes_verbose(host_id, "/repo"),
  )
  assert_eq(remotes.length(), 2)
  assert_eq(remotes[0].name, "origin")
  assert_true(remotes[0].value.contains("(fetch)"))
  assert_true(remotes[1].value.contains("(push)"))

  js_destroy_host(host_id)
}

///|
test "js exports: sparse checkout flow" {
  let host_id = js_create_memory_host()

  js_exports_unwrap_ok("init sparse", js_git_init(host_id, "/sparse", "main"))
  js_exports_unwrap_ok(
    "write keep",
    js_host_write_string(host_id, "/sparse/keep/file.txt", "keep\n"),
  )
  js_exports_unwrap_ok(
    "write skip",
    js_host_write_string(host_id, "/sparse/skip/file.txt", "skip\n"),
  )
  js_exports_unwrap_ok(
    "add sparse",
    js_add_paths(host_id, "/sparse", ["keep/file.txt", "skip/file.txt"]),
  )
  ignore(
    js_exports_unwrap_ok(
      "commit sparse",
      js_commit(
        host_id, "/sparse", "base", "Tester <tester@example.com>", 1700000500,
      ),
    ),
  )

  js_exports_unwrap_ok(
    "sparseCheckoutInit",
    js_sparse_checkout_init(host_id, "/sparse", false),
  )
  js_exports_unwrap_ok(
    "sparseCheckoutSet",
    js_sparse_checkout_set(host_id, "/sparse", ["keep"]),
  )
  assert_true(
    js_exports_unwrap_ok(
      "sparseCheckoutEnabled",
      js_sparse_checkout_enabled(host_id, "/sparse"),
    ),
  )
  assert_false(
    js_exports_unwrap_ok(
      "sparseCheckoutConeEnabled",
      js_sparse_checkout_cone_enabled(host_id, "/sparse"),
    ),
  )
  assert_eq(
    js_exports_unwrap_ok(
      "sparseDisplayPatterns",
      js_sparse_checkout_display_patterns(host_id, "/sparse"),
    ),
    ["keep"],
  )
  assert_true(
    js_exports_unwrap_ok(
      "read keep",
      js_host_read_string(host_id, "/sparse/keep/file.txt"),
    ) ==
    "keep\n",
  )
  assert_true(
    js_exports_unwrap_ok(
      "status after sparse set",
      js_status(host_id, "/sparse"),
    ).unstaged_deleted.contains("skip/file.txt"),
  )

  js_exports_unwrap_ok(
    "sparseCheckoutAdd",
    js_sparse_checkout_add(host_id, "/sparse", ["skip"]),
  )
  let patterns_after_add = js_exports_unwrap_ok(
    "sparseDisplayPatterns after add",
    js_sparse_checkout_display_patterns(host_id, "/sparse"),
  )
  assert_true(patterns_after_add.contains("keep"))
  assert_true(patterns_after_add.contains("skip"))
  js_exports_unwrap_ok(
    "sparseCheckoutReapply",
    js_sparse_checkout_reapply(host_id, "/sparse"),
  )
  assert_eq(
    js_exports_unwrap_ok(
      "read skip",
      js_host_read_string(host_id, "/sparse/skip/file.txt"),
    ),
    "skip\n",
  )

  js_exports_unwrap_ok(
    "sparseCheckoutDisable",
    js_sparse_checkout_disable(host_id, "/sparse"),
  )
  assert_false(
    js_exports_unwrap_ok(
      "sparseCheckoutEnabled after disable",
      js_sparse_checkout_enabled(host_id, "/sparse"),
    ),
  )
  let patterns = js_exports_unwrap_ok(
    "sparseCheckoutPatterns",
    js_sparse_checkout_patterns(host_id, "/sparse"),
  )
  assert_true(patterns.length() > 0)
  assert_eq(
    js_exports_unwrap_ok(
      "read skip after disable",
      js_host_read_string(host_id, "/sparse/skip/file.txt"),
    ),
    "skip\n",
  )

  js_destroy_host(host_id)
}
