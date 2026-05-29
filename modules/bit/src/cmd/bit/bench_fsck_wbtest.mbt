///| Benchmarks for fsck command
///
/// Run with:
/// - moon bench -p mizchi/bit/cmd/bit --target native -f bench_fsck_wbtest.mbt

///|
let bench_fsck_root : String = "/tmp/bit_bench_fsck_v1"

///|
fn bench_fsck_create_repo(
  repo_path : String,
  num_commits : Int,
  files_per_commit : Int,
) -> Unit {
  ensure_bench_dir(repo_path)
  let fs = OsFs::new()
  ignore(try? @bitrepo.init_repo(fs, repo_path))
  for commit_idx in 0..<num_commits {
    let dir = repo_path + "/dir_\{commit_idx}"
    ensure_bench_dir(dir)
    for file_idx in 0..<files_per_commit {
      @fs.write_string_to_file(
        dir + "/file_\{file_idx}.txt",
        "fsck bench content \{commit_idx}-\{file_idx}\n",
      ) catch {
        _ => ()
      }
    }
    @async.run_async_main(async fn() {
      ignore(try? @bitlib.add_paths_async(fs, fs, repo_path, ["."]))
    })
    ignore(
      try? @bitlib.commit(
        fs,
        fs,
        repo_path,
        "commit \{commit_idx}\n",
        "Bench <bench@example.com>",
        1700000000L + commit_idx.to_int64(),
      ),
    )
  }
}

///|
fn bench_fsck_ensure_repos() -> Unit {
  let marker = bench_fsck_root + "/.ready"
  ensure_bench_dir(bench_fsck_root)
  if @fs.path_exists(marker) {
    return
  }
  // Small: 5 commits × 10 files ≈ 70 objects (loose)
  bench_fsck_create_repo(bench_fsck_root + "/small", 5, 10)
  // Medium: 20 commits × 20 files ≈ 460 objects (loose)
  bench_fsck_create_repo(bench_fsck_root + "/medium", 20, 20)
  // Packed: same as medium but repacked
  bench_fsck_create_repo(bench_fsck_root + "/packed", 20, 20)
  @async.run_async_main(async fn() {
    run_main_for_args([
      "bit",
      "-C",
      bench_fsck_root + "/packed",
      "repack",
      "-a",
      "-d",
    ])
  })
  @fs.write_string_to_file(marker, "ok\n") catch {
    _ => ()
  }
}

///|
test "bench fsck small (70 obj, loose)" (b : @bench.T) {
  bench_fsck_ensure_repos()
  bench_reset_env()
  let repo = bench_fsck_root + "/small"
  let args = ["bit", "-C", repo, "fsck", "--no-dangling"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
test "bench fsck medium (460 obj, loose)" (b : @bench.T) {
  bench_fsck_ensure_repos()
  bench_reset_env()
  let repo = bench_fsck_root + "/medium"
  let args = ["bit", "-C", repo, "fsck", "--no-dangling"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
test "bench fsck medium (460 obj, packed)" (b : @bench.T) {
  bench_fsck_ensure_repos()
  bench_reset_env()
  let repo = bench_fsck_root + "/packed"
  let args = ["bit", "-C", repo, "fsck", "--no-dangling"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
test "bench fsck connectivity-only medium" (b : @bench.T) {
  bench_fsck_ensure_repos()
  bench_reset_env()
  let repo = bench_fsck_root + "/medium"
  let args = ["bit", "-C", repo, "fsck", "--connectivity-only", "--no-dangling"]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
