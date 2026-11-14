///| Tests for async ignore-aware list_working_files behavior

///|
async test "ignore async: symlink dir is not traversed" {
  @bitnative.init_worktree_probe()
  let fs = @osfs.OsFs::new()
  let mk = @process.run(
    "mktemp",
    ["-d", "/tmp/bit_ignore_symlink.XXXXXX"],
    inherit_env=true,
    stdout=Collect,
    stderr=Collect,
  ) catch {
    _ => return ()
  }
  let (code, stdout, _) = (mk.exit_code, mk.stdout_binary(), mk.stderr_binary())
  if code != 0 {
    return ()
  }
  let root = @utf8.decode(stdout) catch { _ => return () }
  let root = root.trim_end().to_owned()
  fs.mkdir_p(root + "/real")
  fs.write_string(root + "/real/file.txt", "ok")
  let ln = @process.run(
    "ln",
    ["-s", root + "/real", root + "/link"],
    inherit_env=true,
    stdout=Collect,
    stderr=Collect,
  ) catch {
    _ => return ()
  }
  let (ln_code, _, _) = (ln.exit_code, ln.stdout_binary(), ln.stderr_binary())
  if ln_code != 0 {
    return ()
  }
  let files = @bitlib.list_working_files_async(fs, root)
  assert_true(files.contains("real/file.txt"))
  assert_true(files.contains("link"))
  assert_true(!files.contains("link/file.txt"))
}
