///| Benchmarks for apply command
///
/// Run with:
/// - moon bench -p mizchi/bit/cmd/bit --target native -f bench_apply_wbtest.mbt

///|
let bench_apply_root : String = "/tmp/bit_bench_apply_v1"

///|
fn bench_apply_ensure_repo() -> Unit {
  let marker = bench_apply_root + "/.ready"
  ensure_bench_dir(bench_apply_root)
  if @fs.path_exists(marker) {
    return
  }
  let repo = bench_apply_root + "/repo"
  ensure_bench_dir(repo)
  let fs = OsFs::new()
  ignore(try? @bitrepo.init_repo(fs, repo))
  // Create base files
  for i in 0..<100 {
    let content = StringBuilder::new()
    for line in 0..<50 {
      content.write_string("line \{line} of file \{i}\n")
    }
    @fs.write_string_to_file(repo + "/file_\{i}.txt", content.to_string()) catch {
      _ => ()
    }
  }
  @async.run_async_main(async fn() {
    ignore(try? @bitlib.add_paths_async(fs, fs, repo, ["."]))
  })
  ignore(
    try? @bitlib.commit(
      fs, fs, repo, "base\n", "Bench <bench@example.com>", 1700000000L,
    ),
  )
  // Generate patch file directly (unified diff format)
  let diff_buf = StringBuilder::new()
  for i in 0..<20 {
    diff_buf.write_string("diff --git a/file_\{i}.txt b/file_\{i}.txt\n")
    diff_buf.write_string("--- a/file_\{i}.txt\n")
    diff_buf.write_string("+++ b/file_\{i}.txt\n")
    diff_buf.write_string("@@ -23,7 +23,7 @@\n")
    diff_buf.write_string(" line 22 of file \{i}\n")
    diff_buf.write_string(" line 23 of file \{i}\n")
    diff_buf.write_string(" line 24 of file \{i}\n")
    diff_buf.write_string("-line 25 of file \{i}\n")
    diff_buf.write_string("+MODIFIED line 25 of file \{i}\n")
    diff_buf.write_string(" line 26 of file \{i}\n")
    diff_buf.write_string(" line 27 of file \{i}\n")
    diff_buf.write_string(" line 28 of file \{i}\n")
  }
  @fs.write_string_to_file(
    bench_apply_root + "/bench.patch",
    diff_buf.to_string(),
  ) catch {
    _ => ()
  }
  @fs.write_string_to_file(marker, "ok\n") catch {
    _ => ()
  }
}

///|
test "bench apply --stat (20 files)" (b : @bench.T) {
  bench_apply_ensure_repo()
  bench_reset_env()
  let repo = bench_apply_root + "/repo"
  let patch = bench_apply_root + "/bench.patch"
  let args = ["bit", "-C", repo, "apply", "--stat", patch]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
test "bench apply --check (20 files)" (b : @bench.T) {
  bench_apply_ensure_repo()
  bench_reset_env()
  let repo = bench_apply_root + "/repo"
  let patch = bench_apply_root + "/bench.patch"
  let args = ["bit", "-C", repo, "apply", "--check", patch]
  b.bench(fn() {
    bench_stdout_suppress()
    @async.run_async_main(async fn() { run_main_for_args(args) })
    bench_stdout_restore()
    b.keep(1)
  })
}

///|
