///| Benchmarks for stash command
///
/// Run with:
/// - moon bench -p mizchi/bit/cmd/bit --target native -f bench_stash_wbtest.mbt

///|
let bench_stash_root : String = "/tmp/bit_bench_stash_v1"

///|
fn bench_stash_ensure_repo() -> Unit {
  let marker = bench_stash_root + "/.ready"
  ensure_bench_dir(bench_stash_root)
  if @fs.path_exists(marker) {
    return
  }
  let repo = bench_stash_root + "/repo"
  ensure_bench_dir(repo)
  let fs = OsFs::new()
  ignore(try? @bitrepo.init_repo(fs, repo))
  // Create base files
  for i in 0..<50 {
    @fs.write_string_to_file(repo + "/file_\{i}.txt", "base content \{i}\n") catch {
      _ => ()
    }
  }
  @async.run_async_main(async fn() {
    ignore(try? @bitlib.add_paths_async(fs, fs, repo, ["."]))
  })
  ignore(
    try? @bitlib.commit(
      fs, fs, repo, "base commit\n", "Bench <bench@example.com>", 1700000000L,
    ),
  )
  // Modify some files and stash
  for i in 0..<10 {
    @fs.write_string_to_file(repo + "/file_\{i}.txt", "modified content \{i}\n") catch {
      _ => ()
    }
  }
  @async.run_async_main(async fn() {
    ignore(try? @bitlib.add_paths_async(fs, fs, repo, ["."]))
  })
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", repo, "stash", "push", "-m", "bench stash"])
  })
  @fs.write_string_to_file(marker, "ok\n") catch {
    _ => ()
  }
}

///|
test "bench stash list" (b : @bench.T) {
  bench_stash_ensure_repo()
  bench_reset_env()
  let repo = bench_stash_root + "/repo"
  let args = ["bit", "-C", repo, "stash", "list"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
test "bench stash show --stat" (b : @bench.T) {
  bench_stash_ensure_repo()
  bench_reset_env()
  let repo = bench_stash_root + "/repo"
  let args = ["bit", "-C", repo, "stash", "show"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
test "bench stash show -p" (b : @bench.T) {
  bench_stash_ensure_repo()
  bench_reset_env()
  let repo = bench_stash_root + "/repo"
  let args = ["bit", "-C", repo, "stash", "show", "-p"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
