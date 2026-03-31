///|
test "component impl: status result helpers collect staged added modified deleted" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/tracked.txt", "base\n")
  fs.write_string("/repo/delete.txt", "delete me\n")
  add_with_fs(fs, fs, "/repo", ["tracked.txt", "delete.txt"])
  ignore(
    commit_with_fs(
      fs, fs, "/repo", "initial\n", "Test <t@example.com>", 1700000000L,
    ),
  )

  fs.write_string("/repo/tracked.txt", "staged\n")
  add_with_fs(fs, fs, "/repo", ["tracked.txt"])
  fs.write_string("/repo/added.txt", "added\n")
  add_with_fs(fs, fs, "/repo", ["added.txt"])
  rm_with_fs(fs, fs, "/repo", ["delete.txt"], false)

  let staged = status_collect_staged_changes(
    fs,
    "/repo/.git",
    @bitlib.read_index_entries(fs, "/repo/.git"),
  )

  assert_eq(staged, StatusStagedChanges::{
    staged_added: ["added.txt"],
    staged_modified: ["tracked.txt"],
    staged_deleted: ["delete.txt"],
  })
}

///|
test "component impl: status result helpers build sorted status result" {
  let result = status_build_result(
    StatusWorktreeChanges::{
      untracked: ["z.txt", "a.txt"],
      unstaged_modified: ["b.txt", "a.txt"],
      unstaged_deleted: ["d.txt", "c.txt"],
    },
    StatusStagedChanges::{
      staged_added: ["z.txt", "a.txt"],
      staged_modified: ["d.txt", "b.txt"],
      staged_deleted: ["y.txt", "x.txt"],
    },
  )

  assert_eq(result, StatusResult::{
    staged_added: ["a.txt", "z.txt"],
    staged_modified: ["b.txt", "d.txt"],
    staged_deleted: ["x.txt", "y.txt"],
    unstaged_modified: ["a.txt", "b.txt"],
    unstaged_deleted: ["c.txt", "d.txt"],
    untracked: ["a.txt", "z.txt"],
  })
}
