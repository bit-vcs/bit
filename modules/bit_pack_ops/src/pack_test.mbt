///|
async test "pack package: collect reachable objects" {
  let fs = @bit.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs.write_string("/repo/a.txt", "hello\n")
  @bitlib.add_paths_async(fs, fs, "/repo", ["a.txt"])
  let commit_id = @bitlib.commit(
    fs, fs, "/repo", "msg\n", "Test <test@example.com>", 1700000000L,
  )
  let db = @bitlib.ObjectDb::load(fs, "/repo/.git")
  let objs = collect_reachable_objects(db, fs, commit_id)
  assert_true(objs.length() > 0)
}
