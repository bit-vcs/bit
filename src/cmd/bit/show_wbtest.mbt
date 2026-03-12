///|
fn show_wbtest_zero_id() -> @bitcore.ObjectId {
  @bitcore.ObjectId::new(FixedArray::make(20, b'\x00'))
}

///|
test "show: render tree lines adds trailing slash for directories" {
  let zero = show_wbtest_zero_id()
  let lines = show_render_tree_lines("HEAD^{tree}", [
    @bitcore.TreeEntry::new("040000", "a", zero),
    @bitcore.TreeEntry::new("100644", "main1.t", zero),
  ])
  let expected =
    #|tree HEAD^{tree}
    #|
    #|a/
    #|main1.t
  assert_eq(lines.join("\n"), expected)
}

///|
test "show: parse tag info reads metadata and message" {
  let zero = show_wbtest_zero_id()
  let text = "object " +
    zero.to_hex() +
    "\ntype commit\ntag annotated\ntagger Test User <test@example.com> 1700000000 +0900\n\nannotated tag\n"
  let data = str_to_bytes(text)
  let info = show_parse_tag_info(data).unwrap()
  assert_eq(info.target, zero)
  assert_eq(info.name, "annotated")
  assert_eq(info.tagger, "Test User <test@example.com>")
  assert_eq(info.timestamp, 1700000000L)
  assert_eq(info.timezone, "+0900")
  assert_eq(info.message, "annotated tag\n")
}

///|
test "show: parse args detects walk mode and graph flag" {
  let count_opts = show_parse_args(["-2", "main3"])
  assert_true(count_opts.walk_mode)
  assert_eq(count_opts.max_count, 2)
  assert_eq(count_opts.revs, ["main3"])

  let range_opts = show_parse_args(["^side3", "main3"])
  assert_true(range_opts.walk_mode)
  assert_eq(range_opts.range_excludes, ["side3"])
  assert_eq(range_opts.revs, ["main3"])

  let tree_opts = show_parse_args(["main1^{tree}"])
  assert_false(tree_opts.walk_mode)
  assert_eq(tree_opts.revs, ["main1^{tree}"])

  let graph_opts = show_parse_args(["--graph", "HEAD"])
  assert_true(graph_opts.graph_requested)
}

///|
test "show: resolves :path against index entries" {
  let fs = @bitcore.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  let zero = show_wbtest_zero_id()
  @bitlib.write_index_entries(fs, git_dir, [
    @bitlib.IndexEntry::new("staged-file", zero, 0o100644, 12),
  ])
  assert_eq(
    show_resolve_index_object_id(fs, git_dir, ":staged-file"),
    Some(zero),
  )
  assert_eq(
    show_resolve_index_object_id(fs, git_dir, ":./staged-file"),
    Some(zero),
  )
  assert_eq(show_resolve_index_object_id(fs, git_dir, ":missing"), None)
}

///|
test "show: pretty format uses generic commit formatter" {
  let fs = @bitcore.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let zero = show_wbtest_zero_id()
  let date = format_show_date(1700000000L, "+0900")
  let commit_text = "tree " +
    zero.to_hex() +
    "\nauthor Alice <alice@example.com> 1700000000 +0900\ncommitter Alice <alice@example.com> 1700000000 +0900\n\nsubject\n\nbody line\n"
  let rendered = show_render_commit_block(
    db,
    fs,
    zero,
    str_to_bytes(commit_text),
    false,
    Some("%an,%ae,%ad%n"),
    true,
    false,
    [],
    GrepPatternType::Basic,
    false,
  ).unwrap()
  let expected = "Alice,alice@example.com,\{date}\n"
  assert_eq(rendered, expected)
}

///|
test "show: pretty format honors body modifiers" {
  let fs = @bitcore.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let zero = show_wbtest_zero_id()
  let commit_text = "tree " +
    zero.to_hex() +
    "\nauthor Alice <alice@example.com> 1700000000 +0900\ncommitter Alice <alice@example.com> 1700000000 +0900\n\nsubject\n\nbody line\n"
  let rendered = show_render_commit_block(
    db,
    fs,
    zero,
    str_to_bytes(commit_text),
    false,
    Some("%s%+bThanks%n"),
    true,
    false,
    [],
    GrepPatternType::Basic,
    false,
  ).unwrap()
  assert_eq(rendered, "subject\nbody line\nThanks\n")
}
