///|
test "component impl: join_path handles root and empty base" {
  inspect(join_path("", "file.txt"), content="file.txt")
  inspect(join_path("/", "file.txt"), content="/file.txt")
  inspect(join_path("/repo", "file.txt"), content="/repo/file.txt")
}

///|
test "component impl: resolve_git_dir joins .git path" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git")
  inspect(resolve_git_dir(fs, "/repo"), content="/repo/.git")
  inspect(resolve_git_dir(fs, "/other"), content="/other/.git")
}
