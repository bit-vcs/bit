///|
test "grep search: searches tracked worktree files only" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\nworld\n")
  fs.write_string("/repo/dir/b.txt", "HELLO\n")
  fs.write_string("/repo/untracked.txt", "hello\n")
  @bitlib.add_paths(fs, fs, "/repo", ["a.txt", "dir/b.txt"])

  let matches = search_tracked_worktree(
    fs,
    "/repo/.git",
    "/repo",
    ["hello"],
    [],
    ignore_case=false,
    invert_match=false,
  )

  inspect(
    matches,
    content=(
      #|[{path: "a.txt", matches: [{line_number: 1, column: 1, line: "hello"}]}]
    ),
  )
}

///|
test "grep search: path filter and ignore-case both apply" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "hello\n")
  fs.write_string("/repo/dir/b.txt", "HELLO\n")
  @bitlib.add_paths(fs, fs, "/repo", ["a.txt", "dir/b.txt"])

  let matches = search_tracked_worktree(
    fs,
    "/repo/.git",
    "/repo",
    ["hello"],
    ["dir"],
    ignore_case=true,
    invert_match=false,
  )

  inspect(
    matches,
    content=(
      #|[{path: "dir/b.txt", matches: [{line_number: 1, column: 1, line: "HELLO"}]}]
    ),
  )
}

///|
test "grep search: matches any pattern in the list" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "world\n")
  @bitlib.add_paths(fs, fs, "/repo", ["a.txt"])

  let matches = search_tracked_worktree(
    fs,
    "/repo/.git",
    "/repo",
    ["hello", "world"],
    [],
  )

  inspect(
    matches,
    content=(
      #|[{path: "a.txt", matches: [{line_number: 1, column: 1, line: "world"}]}]
    ),
  )
}

///|
test "grep search: cached reads index blob instead of worktree file" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "cached\n")
  @bitlib.add_paths(fs, fs, "/repo", ["a.txt"])
  fs.write_string("/repo/a.txt", "worktree\n")

  let matches = search_index(fs, "/repo/.git", ["cached"], [])

  inspect(
    matches,
    content=(
      #|[{path: "a.txt", matches: [{line_number: 1, column: 1, line: "cached"}]}]
    ),
  )
}

///|
test "grep search: treeish reads committed tree instead of worktree file" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/a.txt", "head\n")
  @bitlib.add_paths(fs, fs, "/repo", ["a.txt"])
  ignore(@bitlib.commit(fs, fs, "/repo", "initial", "T <t@example.com>", 1L))
  fs.write_string("/repo/a.txt", "worktree\n")

  let matches = search_treeish(fs, "/repo/.git", "HEAD", ["head"], [])

  inspect(
    matches,
    content=(
      #|[{path: "HEAD:a.txt", matches: [{line_number: 1, column: 1, line: "head"}]}]
    ),
  )
}

///|
test "grep search: max depth limits treeish path traversal" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/v", "vvv\n")
  fs.write_string("/repo/t/v", "vvv\n")
  fs.write_string("/repo/t/a/v", "vvv\n")
  @bitlib.add_paths(fs, fs, "/repo", ["v", "t/v", "t/a/v"])
  ignore(@bitlib.commit(fs, fs, "/repo", "initial", "T <t@example.com>", 1L))

  let matches = search_treeish(
    fs,
    "/repo/.git",
    "HEAD",
    ["vvv"],
    ["t"],
    max_depth=0,
  )

  inspect(
    matches,
    content=(
      #|[{path: "HEAD:t/v", matches: [{line_number: 1, column: 1, line: "vvv"}]}]
    ),
  )
}

///|
test "grep search: wildcard pathspec keeps recursive treeish matches" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/v", "vvv\n")
  fs.write_string("/repo/t/v", "vvv\n")
  fs.write_string("/repo/t/a/v", "vvv\n")
  @bitlib.add_paths(fs, fs, "/repo", ["v", "t/v", "t/a/v"])
  ignore(@bitlib.commit(fs, fs, "/repo", "initial", "T <t@example.com>", 1L))

  let matches = search_treeish(
    fs,
    "/repo/.git",
    "HEAD",
    ["vvv"],
    ["*"],
    max_depth=0,
  )

  inspect(
    matches,
    content=(
      #|[{path: "HEAD:t/a/v", matches: [{line_number: 1, column: 1, line: "vvv"}]}, {path: "HEAD:t/v", matches: [{line_number: 1, column: 1, line: "vvv"}]}, {path: "HEAD:v", matches: [{line_number: 1, column: 1, line: "vvv"}]}]
    ),
  )
}

///|
test "grep search: word regexp keeps whole-word matches and reports first column" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string(
    "/repo/file", "foo mmap bar\nfoo_mmap bar\nfoo_mmap bar mmap\nfoo mmap bar_mmap\n",
  )
  @bitlib.add_paths(fs, fs, "/repo", ["file"])
  ignore(@bitlib.commit(fs, fs, "/repo", "initial", "T <t@example.com>", 1L))

  let matches = search_treeish(
    fs,
    "/repo/.git",
    "HEAD",
    ["mmap"],
    ["file"],
    word_regexp=true,
  )

  inspect(
    matches,
    content=(
      #|[{path: "HEAD:file", matches: [{line_number: 1, column: 5, line: "foo mmap bar"}, {line_number: 3, column: 14, line: "foo_mmap bar mmap"}, {line_number: 4, column: 5, line: "foo mmap bar_mmap"}]}]
    ),
  )
}

///|
test "grep search: plain worktree search includes ignored files unless excluded" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo")
  fs.write_string("/repo/.gitignore", "*.skip\n")
  fs.write_string("/repo/keep.txt", "hello\n")
  fs.write_string("/repo/drop.skip", "hello\n")

  let all_matches = search_plain_worktree_expr(
    fs,
    "/repo",
    GrepExpr::Pattern("hello"),
    [],
  )
  inspect(
    all_matches,
    content=(
      #|[{path: "drop.skip", matches: [{line_number: 1, column: 1, line: "hello"}]}, {path: "keep.txt", matches: [{line_number: 1, column: 1, line: "hello"}]}]
    ),
  )

  let visible_matches = search_plain_worktree_expr(
    fs,
    "/repo",
    GrepExpr::Pattern("hello"),
    [],
    exclude_standard=true,
  )
  inspect(
    visible_matches,
    content=(
      #|[{path: "keep.txt", matches: [{line_number: 1, column: 1, line: "hello"}]}]
    ),
  )
}

///|
test "grep search: plain worktree descends into nested repos but skips .git" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/top.txt", "magic\n")
  @bitlib.init_repo(fs, "/repo/nested")
  fs.write_string("/repo/nested/file", "magic\n")
  fs.write_string("/repo/nested/.git/file", "magic\n")

  let matches = search_plain_worktree_expr(
    fs,
    "/repo",
    GrepExpr::Pattern("magic"),
    [],
  )
  inspect(
    matches,
    content=(
      #|[{path: "nested/file", matches: [{line_number: 1, column: 1, line: "magic"}]}, {path: "top.txt", matches: [{line_number: 1, column: 1, line: "magic"}]}]
    ),
  )
}

///|
test "grep search: untracked search respects ignore rules" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/.gitignore", ".*o*\n")
  fs.write_string("/repo/file1", "hello\n")
  fs.mkdir_p("/repo/sub")
  fs.write_string("/repo/sub/file2", "world\n")

  let matches = search_untracked_worktree_expr(
    fs,
    "/repo/.git",
    "/repo",
    GrepExpr::Pattern("o"),
    [],
  )
  inspect(
    matches,
    content=(
      #|[{path: "file1", matches: [{line_number: 1, column: 5, line: "hello"}]}, {path: "sub/file2", matches: [{line_number: 1, column: 2, line: "world"}]}]
    ),
  )
}
