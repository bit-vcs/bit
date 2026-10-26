///| Ensure lib algorithms work with pure MoonBit I/O defaults.

///|
async test "lib pure runtime: status/add_paths_async without native init" {
  @bitio.set_env_provider(@bitio.EnvProvider::none())
  @bitio.set_worktree_probe(@bitio.WorktreeProbeProvider::none())
  let fs = @bit.TestFs::new()
  ignore(@bit_lib.init_repo(fs, "/repo")) catch {
    _ => ()
  }
  fs.write_string("/repo/a.txt", "hello\n")
  let st_before = @bit_lib.status(fs, "/repo")
  debug_inspect(
    st_before.untracked,
    content=(
      #|["a.txt"]
    ),
  )
  @bit_lib.add_paths_async(fs, fs, "/repo", ["a.txt"])
  let st_after = @bit_lib.status(fs, "/repo")
  debug_inspect(
    st_after.staged_added,
    content=(
      #|["a.txt"]
    ),
  )
  debug_inspect(st_after.unstaged_modified, content="[]")
}
