///|
async test "pack package: collect reachable objects" {
  let fs = @git.TestFs::new()
  ignore(try? @gitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/a.txt", "hello\n")
  @gitlib.add_paths_async(fs, fs, "/repo", ["a.txt"])
  let commit_id = @gitlib.commit(
    fs, fs, "/repo", "msg\n", "Test <test@example.com>", 1700000000L,
  )
  let db = @gitlib.ObjectDb::load(fs, "/repo/.git")
  let objs = collect_reachable_objects(db, fs, commit_id)
  assert_true(objs.length() > 0)
}
