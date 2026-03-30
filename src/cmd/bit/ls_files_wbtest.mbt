///|
test "ls-files: no wildcard filter matches exact path" {
  assert_true(ls_files_matches_filters("a.txt", ["a.txt"]))
  assert_true(!(ls_files_matches_filters("dir/b.txt", ["a.txt"])))
}

///|
test "ls-files: directory prefix filter works" {
  assert_true(ls_files_matches_filters("dir/a.txt", ["dir"]))
  assert_true(!(ls_files_matches_filters("other.txt", ["dir"])))
}

///|
test "ls-files: trailing slash filter matches directory output" {
  assert_true(ls_files_matches_filters("untracked/deep/", ["untracked/deep/"]))
  assert_true(
    ls_files_matches_filters("partially_tracked/untracked_dir/", [
      "partially_tracked/",
    ]),
  )
}

///|
test "ls-files: wildcard directory filter matches directory output" {
  assert_true(ls_files_matches_filters("untracked/deep/", ["untracked/?*"]))
}

///|
test "ls-files: wildcard prefix filter" {
  let long_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  assert_true(ls_files_matches_filters(long_name, ["a*"]))
  assert_true(!(ls_files_matches_filters("b.txt", ["a*"])))
}

///|
test "ls-files: normalize keeps wildcard filter as-is" {
  assert_eq(normalize_ls_tree_filters(["a*"], ""), ["a*"])
}

///|
test "ls-files: absolute filter inside repo becomes repo-relative" {
  assert_eq(normalize_ls_files_filters(["/repo/subs/link"], "subs", "/repo"), [
    "subs/link",
  ])
}

///|
test "ls-files: absolute filter outside repo stays absolute" {
  assert_eq(normalize_ls_files_filters(["/outside/link"], "subs", "/repo"), [
    "/outside/link",
  ])
}

///|
test "ls-files: normalize preserves pathspec magic" {
  assert_eq(
    normalize_ls_files_filters([":(exclude)../submodule"], "b", "/repo"),
    [":(exclude)submodule"],
  )
}

///|
test "ls-files: wildcard filter matches index scan" {
  let entries = [ls_files_entry("a_long_path.txt"), ls_files_entry("other.txt")]
  assert_true(
    entries
    .iter()
    .any(fn(entry) { ls_files_pathspec_matches(entry.path, "a*") }),
  )
  assert_true(
    !(
      entries
      .iter()
      .any(fn(entry) { ls_files_pathspec_matches(entry.path, "b*") }),
    ),
  )
}

///|
test "ls-files: icase pathspec matches case-insensitively" {
  assert_true(ls_files_matches_filters("submodule/f.TXT", [":(icase)*.txt"]))
  assert_true(
    ls_files_matches_filters("submodule/subsub/e.txt", [":(icase)*.txt"]),
  )
}

///|
test "ls-files: exclude pathspec removes matching entries" {
  let filters = [":(icase)*.txt", ":(exclude)submodule/subsub/*"]
  assert_true(ls_files_matches_filters("submodule/g.txt", filters))
  assert_true(!(ls_files_matches_filters("submodule/subsub/e.txt", filters)))
}

///|
test "ls-files: compare directory and file suffix order" {
  assert_true(ls_files_compare_paths("path2-junk", "path2/") < 0)
  assert_true(ls_files_compare_paths("path2/", "path4/") < 0)
}

///|
test "ls-files: display path relativizes sibling and parent paths" {
  assert_eq(make_display_path("top/x", "top/sub"), "../x")
  assert_eq(
    make_display_path("never-mind-me", "top/sub"),
    "../../never-mind-me",
  )
  assert_eq(make_display_path("top/dir/", "top/sub"), "../dir/")
}

///|
test "ls-files: cwd prefix falls back to PWD when shim pwd is absent" {
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_pwd = @sys.get_env_var("PWD")
  @sys.unset_env_var("GIT_SHIM_PWD")
  @sys.set_env_var("PWD", "/repo/sub")
  assert_eq(compute_cwd_prefix("/repo"), "sub")
  match prev_shim_pwd {
    Some(value) => @sys.set_env_var("GIT_SHIM_PWD", value)
    None => @sys.unset_env_var("GIT_SHIM_PWD")
  }
  match prev_pwd {
    Some(value) => @sys.set_env_var("PWD", value)
    None => @sys.unset_env_var("PWD")
  }
}

///|
test "ls-files: untracked directory compression" {
  assert_true(ls_files_is_within_untracked_dir("untracked/deep", ["untracked"]))
  assert_true(
    ls_files_is_within_untracked_dir("partially_tracked/untracked/file.txt", [
      "partially_tracked/untracked",
    ]),
  )
  assert_true(
    !(
      ls_files_is_within_untracked_dir("partially_tracked/tracked.txt", [
        "partially_tracked/untracked",
      ]),
    ),
  )
}

///|
test "ls-files: has matching file under directory" {
  let files = ["src/main.rs", "src/lib/main.rs", "readme.md"]
  let untracked : Map[String, Bool] = { "src/main.rs": true, "readme.md": true }
  assert_true(ls_files_has_matching_file("src", files, untracked))
  assert_true(!(ls_files_has_matching_file("tests", files, untracked)))
}

///|
fn ls_files_entry(path : String) -> @bitlib.IndexEntry {
  @bitlib.IndexEntry::new(
    path,
    @bitcore.ObjectId::new(FixedArray::make(20, b'\x00')),
    0,
    0,
  )
}
