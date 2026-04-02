///|
test "tag: cleanup file message strips comments and surrounding blanks" {
  let input =
    #|
    #|# A comment
    #|
    #|  Leading blank lines
    #|
    #|Repeated blank lines
    #|
    #|Trailing spaces      
    #|
    #|# ignored
    #|
  let expected =
    #|  Leading blank lines
    #|
    #|Repeated blank lines
    #|
    #|Trailing spaces
  assert_eq(tag_cleanup_message(input), expected)
}

///|
test "tag: cleanup treats comment-only inline messages as empty" {
  assert_eq(tag_cleanup_message("#comment"), "")
  assert_eq(tag_cleanup_message("     "), "")
}

///|
test "tag: ignore-case sort uses folded refname" {
  assert_true(tag_sort_compare("tag-one", "TAG-two", "refname", true) < 0)
  assert_true(tag_sort_compare("TAG-two", "tag-one", "refname", true) > 0)
}

///|
test "tag: default sort is lexical" {
  assert_true(tag_default_compare("v0.2.1", "v1.0", false) < 0)
  assert_true(tag_default_compare("v1.0", "v1.0.1", false) < 0)
}

///|
test "tag: annotation output aligns first line without extra separator" {
  let lines = tag_format_annotation_lines("tag-one-line", ["A msg"])
  assert_eq(lines.join("\n"), "tag-one-line    A msg")
}

///|
test "tag: annotation output indents continuation lines" {
  let lines = tag_format_annotation_lines("tag-lines", [
    "tag line one", "tag line two",
  ])
  assert_eq(lines.join("\n"), "tag-lines       tag line one\n    tag line two")
}

///|
test "tag: editor template starts with blank line when message is absent" {
  let template = tag_edit_buffer_template(None)
  assert_eq(string_slice_to(template, 1), "\n")
}

///|
test "tag: short option bundles expand annotate and message" {
  assert_eq(tag_expand_short_bundles(["-am", "msg", "v1"]), [
    "-a", "-m", "msg", "v1",
  ])
  assert_eq(tag_expand_short_bundles(["-ammsg", "v1"]), ["-a", "-mmsg", "v1"])
  assert_eq(tag_expand_short_bundles(["-n2", "v1"]), ["-n2", "v1"])
}

///|
async test "tag: short option bundle -am creates annotated tag" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-tag-short-bundle-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  grep_test_run_git(root, ["init", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/tracked.txt", "seed\n")
  grep_test_run_git(repo_dir, ["add", "tracked.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "initial"])
  grep_test_run_git(repo_dir, ["tag", "-am", "bundled", "v1", "HEAD"])

  let tag_body = grep_test_git_stdout(repo_dir, ["cat-file", "tag", "v1"])
  assert_true(tag_body.contains("\n\nbundled\n"))

  cleanup_tree(fs, root)
}

///|
async test "tag: -s stores signature block via configured signing program" {
  @bitnative.init_native_io()
  cmd_bit_wbtest_env_lock.acquire()
  defer cmd_bit_wbtest_env_lock.release()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-tag-sign-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")
  defer add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  defer add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  defer add_test_restore_env("GIT_DIR", prev_git_dir)
  defer add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  grep_test_run_git(root, ["init", "-q", "repo"])
  grep_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  grep_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  let signer = root + "/fake-gpg.sh"
  signing_wbtest_write_fake_gpg(fs, signer)
  grep_test_run_git(repo_dir, ["config", "gpg.program", signer])
  grep_test_run_git(repo_dir, ["config", "gpg.format", "openpgp"])
  fs.write_string(repo_dir + "/tracked.txt", "seed\n")
  grep_test_run_git(repo_dir, ["add", "tracked.txt"])
  grep_test_run_git(repo_dir, ["commit", "-q", "-m", "initial"])

  @sys.unset_env_var("GIT_SHIM_CWD")
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)

  handle_tag(["-s", "-m", "signed tag", "v1"]) catch {
    err => fail("handle_tag failed: \{err}")
  }

  let git_dir = repo_dir + "/.git"
  let tag_id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/v1").unwrap()
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let tag_obj = db.get(fs, tag_id).unwrap()
  let tag_text = @utf8.decode_lossy(tag_obj.data[:]).to_string()
  assert_true(tag_text.contains("signed tag\n-----BEGIN PGP SIGNATURE-----\n"))
  assert_true(tag_text.contains("\nabc123\n"))
  assert_true(tag_text.contains("\n-----END PGP SIGNATURE-----\n"))

  cleanup_tree(fs, root)
}

///|
test "tag: sort field aliases normalize to refname variants" {
  assert_eq(tag_normalize_sort_field("tag"), "refname")
  assert_eq(tag_normalize_sort_field("version:tag"), "version:refname")
}

///|
test "tag: validate tag name rejects invalid forms" {
  assert_true(tag_is_valid_name("release/v1.0"))
  assert_true(!tag_is_valid_name(".othertag"))
  assert_true(!tag_is_valid_name("other tag"))
  assert_true(!tag_is_valid_name("othertag^"))
  assert_true(!tag_is_valid_name("other~tag"))
}

///|
test "tag: reflog message formatting matches git" {
  assert_eq(
    tag_reflog_message("1234567", "Foo", "2026-03-09"),
    "tag: tagging 1234567 (Foo, 2026-03-09)",
  )
}

///|
test "tag: contains aliases normalize to canonical filter keys" {
  assert_eq(
    tag_parse_contains_style_option("--with", None),
    Some(("contains", "HEAD", 0)),
  )
  assert_eq(
    tag_parse_contains_style_option("--without", None),
    Some(("no_contains", "HEAD", 0)),
  )
  assert_eq(
    tag_parse_contains_style_option("--with=main", None),
    Some(("contains", "main", 0)),
  )
  assert_eq(
    tag_parse_contains_style_option("--without=main", None),
    Some(("no_contains", "main", 0)),
  )
}

///|
test "tag: contains-style options consume explicit revs and reject following options" {
  assert_eq(
    tag_parse_contains_style_option("--contains", Some("topic")),
    Some(("contains", "topic", 1)),
  )
  assert_eq(
    tag_parse_contains_style_option("--no-contains", Some("topic")),
    Some(("no_contains", "topic", 1)),
  )
  assert_eq(
    tag_parse_contains_style_option("--contains", Some("--no-contains")),
    Some(("invalid", "--contains", 0)),
  )
}

///|
test "tag: nested advice text matches git" {
  let lines = tag_nested_advice_lines("nested", "annotated-v4.0")
  let expected =
    #|hint: You have created a nested tag. The object referred to by your new tag is
    #|hint: already a tag. If you meant to tag the object that it points to, use:
    #|hint:
    #|hint: 	git tag -f nested annotated-v4.0^{}
    #|hint: Disable this message with "git config set advice.nestedTag false"
  assert_eq(lines.join("\n"), expected)
}

///|
test "tag: trailer args normalize to key-value lines" {
  assert_eq(tag_normalize_trailer_arg("my-trailer=here"), "my-trailer: here")
  assert_eq(
    tag_normalize_trailer_arg("alt-trailer=there"),
    "alt-trailer: there",
  )
}

///|
test "tag: trailers append after a blank separator" {
  let message = tag_apply_trailers("create tag with trailers", [
    "my-trailer: here", "alt-trailer: there",
  ])
  let expected =
    #|create tag with trailers
    #|
    #|my-trailer: here
    #|alt-trailer: there
  assert_eq(message, expected)
}

///|
test "tag: trailer-only edit buffer keeps a leading blank line" {
  let message = tag_apply_trailers_for_edit("", [
    "my-trailer: here", "alt-trailer: there",
  ])
  let expected =
    #|
    #|my-trailer: here
    #|alt-trailer: there
  assert_eq(message, expected)
}

///|
test "tag: extract message lines keeps commit subject for lightweight tags" {
  let commit_text =
    #|tree deadbeef
    #|author Test <test@example.com> 1700000000 +0900
    #|committer Test <test@example.com> 1700000000 +0900
    #|
    #|Foo
    #|Bar
    #|
  assert_eq(tag_extract_message_lines(commit_text, 1).join("\n"), "Foo")
  assert_eq(tag_extract_message_lines(commit_text, 2).join("\n"), "Foo\nBar")
}

///|
test "tag: versionsort parse detects missing values" {
  let text =
    #|[versionsort]
    #|  prereleaseSuffix
    #|  suffix
  let (suffix_values, prerelease_values, missing_suffix, missing_prerelease) = tag_versionsort_parse_config_text(
    text,
  )
  assert_eq(suffix_values.length(), 0)
  assert_eq(prerelease_values.length(), 0)
  assert_true(missing_suffix)
  assert_true(missing_prerelease)
}

///|
test "tag: versionsort prerelease suffix reorders before base" {
  assert_true(
    tag_version_compare_with_suffixes("foo1.6-rc1", "foo1.6", ["-rc"]) < 0,
  )
  assert_true(
    tag_version_compare_with_suffixes("foo1.6-rc2", "foo1.6-rc1", ["-rc"]) > 0,
  )
}

///|
test "tag: versionsort general suffix order honors configured empty entry" {
  let suffixes = ["-alpha", "-beta", "", "-gamma", "-delta"]
  assert_true(
    tag_version_compare_with_suffixes("foo1.10-beta", "foo1.10", suffixes) < 0,
  )
  assert_true(
    tag_version_compare_with_suffixes("foo1.10", "foo1.10-gamma", suffixes) < 0,
  )
  assert_true(
    tag_version_compare_with_suffixes(
      "foo1.10-unlisted-suffix", "foo1.10-gamma", suffixes,
    ) <
    0,
  )
}

///|
test "tag: column row layout uses global max width by default" {
  let lines = tag_format_columns(
    ["a1", "aa1", "cba", "t210", "t211", "v0.2.1", "v1.0", "v1.0.1", "v1.1.3"],
    41,
    dense=false,
  )
  let expected =
    #|a1      aa1     cba     t210    t211
    #|v0.2.1  v1.0    v1.0.1  v1.1.3
  assert_eq(lines.join("\n"), expected)
}

///|
test "tag: column dense layout uses per-column widths" {
  let lines = tag_format_columns(
    ["a1", "aa1", "cba", "t210", "t211", "v0.2.1", "v1.0", "v1.0.1", "v1.1.3"],
    40,
    dense=true,
  )
  let expected =
    #|a1      aa1   cba     t210    t211
    #|v0.2.1  v1.0  v1.0.1  v1.1.3
  assert_eq(lines.join("\n"), expected)
}
