///|
test "component impl: log_with_fs returns commits in reverse chronological order" {
  let fs = @bit.TestFs::new()
  git_init_with_fs(fs, "/repo", "main")
  fs.write_string("/repo/hello.txt", "v1\n")
  add_with_fs(fs, fs, "/repo", ["hello.txt"])
  let first = commit_with_fs(
    fs, fs, "/repo", "first\n", "Test <t@example.com>", 1700000000L,
  )

  fs.write_string("/repo/hello.txt", "v2\n")
  add_with_fs(fs, fs, "/repo", ["hello.txt"])
  let second = commit_with_fs(
    fs, fs, "/repo", "second\n", "Test <t@example.com>", 1700000001L,
  )

  assert_eq(log_with_fs(fs, "/repo", 10), [
    LogEntry::{
      id: second,
      author: "Test <t@example.com>",
      message: "second",
      timestamp: 1700000001L,
    },
    LogEntry::{
      id: first,
      author: "Test <t@example.com>",
      message: "first",
      timestamp: 1700000000L,
    },
  ])
}
