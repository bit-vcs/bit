///| E2E benchmarks for grep command
///  Measures large-repository grep throughput across worktree/index/tree-ish modes

///|
/// Run with:
/// - moon bench -p mizchi/bit/cmd/bit --target native -f bench_grep_wbtest.mbt

///|
let bench_grep_root : String = "/tmp/bit_bench_grep_v1"

///|
let bench_grep_medium : String = bench_grep_root + "/medium"

///|
let bench_grep_large : String = bench_grep_root + "/large"

///|
let bench_grep_token : String = "BENCH_RARE_TOKEN"

///|
fn bench_grep_cleanup_tree(fs : OsFs, path : String) -> Unit {
  if fs.is_file(path) {
    fs.remove_file(path) catch {
      _ => ()
    }
    return
  }
  if !(fs.is_dir(path)) {
    return
  }
  let entries = fs.readdir(path) catch { _ => [] }
  for entry in entries {
    if entry == "." || entry == ".." {
      continue
    }
    bench_grep_cleanup_tree(fs, path + "/" + entry)
  }
  fs.remove_dir(path) catch {
    _ => ()
  }
}

///|
fn bench_grep_init_probe() -> Unit {
  @bitnative.init_native_io()
}

///|
fn bench_grep_file_body(
  file_idx : Int,
  lines_per_file : Int,
  hit_interval : Int,
) -> String {
  let buf = StringBuilder::new()
  for line_idx in 0..<lines_per_file {
    buf.write_string(
      "line=\{line_idx} file=\{file_idx} payload lorem ipsum dolor sit amet\n",
    )
  }
  if file_idx % hit_interval == 0 {
    buf.write_string("rare match \{bench_grep_token} file=\{file_idx}\n")
  }
  buf.to_string()
}

///|
fn bench_grep_ensure_repo(
  repo_root : String,
  dir_count : Int,
  files_per_dir : Int,
  lines_per_file : Int,
  hit_interval : Int,
) -> Unit {
  let marker = repo_root + "/.bench_ready"
  if @fs.path_exists(marker) {
    return
  }
  bench_grep_init_probe()
  let fs = OsFs::new()
  ensure_bench_dir(bench_grep_root)
  bench_grep_cleanup_tree(fs, repo_root)
  ensure_bench_dir(repo_root)
  ignore(try? @bitrepo.init_repo(fs, repo_root))
  let mut file_idx = 0
  for dir_idx in 0..<dir_count {
    let dir = repo_root + "/dir_\{dir_idx}"
    ensure_bench_dir(dir)
    for item_idx in 0..<files_per_dir {
      let path = dir + "/file_\{item_idx}.txt"
      @fs.write_string_to_file(
        path,
        bench_grep_file_body(file_idx, lines_per_file, hit_interval),
      ) catch {
        _ => ()
      }
      file_idx += 1
    }
  }
  @async.run_async_main(async fn() {
    ignore(try? @bitlib.add_paths_async(fs, fs, repo_root, ["."]))
  })
  ignore(
    try? @bitlib.commit(
      fs, fs, repo_root, "bench grep seed\n", "Bench <bench@example.com>", 1700000000L,
    ),
  )
  @fs.write_string_to_file(marker, "ok\n") catch {
    _ => ()
  }
}

///|
fn bench_grep_run(repo_root : String, args : Array[String]) -> Int {
  bench_grep_init_probe()
  bench_reset_env()
  bench_stdout_suppress()
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", repo_root] + args)
  })
  bench_stdout_restore()
  1
}

///|
test "bench grep worktree medium literal" (b : @bench.T) {
  bench_grep_ensure_repo(bench_grep_medium, 20, 50, 12, 25)
  b.bench(fn() {
    b.keep(bench_grep_run(bench_grep_medium, ["grep", bench_grep_token]))
  })
}

///|
test "bench grep worktree large literal" (b : @bench.T) {
  bench_grep_ensure_repo(bench_grep_large, 50, 100, 12, 40)
  b.bench(fn() {
    b.keep(bench_grep_run(bench_grep_large, ["grep", bench_grep_token]))
  })
}

///|
test "bench grep cached large literal" (b : @bench.T) {
  bench_grep_ensure_repo(bench_grep_large, 50, 100, 12, 40)
  b.bench(fn() {
    b.keep(
      bench_grep_run(bench_grep_large, ["grep", "--cached", bench_grep_token]),
    )
  })
}

///|
test "bench grep head large literal" (b : @bench.T) {
  bench_grep_ensure_repo(bench_grep_large, 50, 100, 12, 40)
  b.bench(fn() {
    b.keep(bench_grep_run(bench_grep_large, ["grep", bench_grep_token, "HEAD"]))
  })
}
