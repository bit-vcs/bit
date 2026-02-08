///|
test "remote-path: resolve helper URL with absolute local path" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/work/server/.git/objects")
  let resolved = resolve_local_repo_path(
    fs, "/work/client", "testgit::/work/server",
  )
  assert_eq(resolved, Some("/work/server"))
}

///|
test "remote-path: resolve helper URL with relative local path" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/work/server/.git/objects")
  let resolved = resolve_local_repo_path(
    fs, "/work/client", "testgit::../server",
  )
  assert_eq(resolved, Some("/work/server"))
}

///|
test "remote-path: ignore non-local scheme URL" {
  let fs = @git.TestFs::new()
  let resolved = resolve_local_repo_path(
    fs, "/work/client", "broken://example.com/repo.git",
  )
  assert_eq(resolved, None)
}

///|
test "remote-path: prefer root-relative resolution for dot-dot path" {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/work/repo/.git/objects")
  let resolved = resolve_local_repo_path(fs, "/work/repo/testrepo", "..")
  assert_eq(resolved, Some("/work/repo"))
}
