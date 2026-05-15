///|
test "remote/path: resolve helper URL with relative local path" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/work/server/.git/objects")
  let resolved = resolve_local_repo_path(
    fs, "/work/client", "testgit::../server",
  )
  assert_eq(resolved, Some("/work/server"))
}

///|
test "remote/path: detect bare git dir" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/bare/objects")
  fs.write_string("/bare/HEAD", "ref: refs/heads/main\n")
  let detected = detect_git_dir(fs, "/bare")
  inspect(detected, content="Some((\"/bare\", true))")
}
