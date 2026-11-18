///|
async fn reset_watch_dir(path : String) -> Unit {
  try @fs.rmdir(path, recursive=true) catch {
    _ => ()
  } noraise {
    _ => ()
  }
  @fs.mkdir(path, permission=0o755, recursive=true)
}

///|
async test "watcher wait_any detects file changes" {
  let dir = "/tmp/mizchi_x_fs_watcher_basic"
  reset_watch_dir(dir)
  let file = dir + "/watched.txt"
  @fs.write_file(file, "before", create_mode=CreateOrTruncate)
  let watcher = @fs.Watcher(dir, debounce_timeout=10, max_debounce_delay=80)
  defer watcher.close()

  @async.sleep(50)
  @fs.write_file(file, "after", create_mode=OpenExisting)
  let observed = @async.with_timeout_opt(1000, () => watcher.wait_any())
  assert_true(observed is Some(_))
  @fs.rmdir(dir, recursive=true)
}

///|
async test "watcher ignored_paths suppresses ignored subtree" {
  let dir = "/tmp/mizchi_x_fs_watcher_ignored"
  reset_watch_dir(dir)
  @fs.mkdir(dir + "/ignored", permission=0o755)
  @fs.mkdir(dir + "/normal", permission=0o755)
  @fs.write_file(dir + "/ignored/file.txt", "before")
  @fs.write_file(dir + "/normal/file.txt", "before")
  let watcher = @fs.Watcher(dir, debounce_timeout=10, max_debounce_delay=80, ignored_paths=path => {
    path == "ignored"
  })
  defer watcher.close()

  let observed : Array[Unit] = []
  @async.with_task_group(group => {
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      watcher.wait_any()
      observed.push(())
    })
    @async.sleep(50)
    @fs.write_file(dir + "/ignored/file.txt", "after", create_mode=OpenExisting)
    @async.sleep(200)
    assert_eq(observed.length(), 0)

    @fs.write_file(dir + "/normal/file.txt", "after", create_mode=OpenExisting)
    for _ in 0..<20 {
      if observed.length() > 0 {
        break
      }
      @async.sleep(50)
    }
    assert_eq(observed.length(), 1)
  })
  @fs.rmdir(dir, recursive=true)
}
