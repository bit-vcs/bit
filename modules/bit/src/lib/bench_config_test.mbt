///| Benchmarks for the config-reading helpers in `lib`. These wrap
/// `@config_parse` with file-IO, so they double-count read + parse
/// cost; useful for spotting opportunities to share parses across
/// adjacent helper calls.
///
/// Run with:
///   moon bench -p mizchi/bit/lib --target native -f bench_config_test.mbt

///|
let bench_config_root : String = "/bench_config"

///|
fn bench_setup_config_repo(num_remotes : Int) -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  let git_dir = bench_config_root + "/.git"
  fs.mkdir_p(git_dir)
  let sb = StringBuilder::new()
  sb.write_string(
    "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tautocrlf = false\n",
  )
  sb.write_string("[extensions]\n\tobjectformat = sha1\n")
  for i in 0..<num_remotes {
    sb.write_string("[remote \"r\{i}\"]\n")
    sb.write_string("\turl = https://example.com/repo\{i}.git\n")
    sb.write_string("\tfetch = +refs/heads/*:refs/remotes/r\{i}/*\n")
  }
  fs.write_string(git_dir + "/config", sb.to_string())
  fs
}

///|
let bench_config_fs_small : @bit.TestFs = bench_setup_config_repo(2)

///|
let bench_config_fs_large : @bit.TestFs = bench_setup_config_repo(100)

///|
test "bench read_config_value small config single key" (b : @bench.T) {
  let config_path = bench_config_root + "/.git/config"
  b.bench(fn() {
    let v = read_config_value(
      bench_config_fs_small,
      config_path,
      "core",
      "autocrlf",
    )
    b.keep(v is Some(_))
  })
}

///|
test "bench read_config_value 4 keys (sequential, re-reads each)" (b : @bench.T) {
  // Mirrors the rev_parse hot spot — back-to-back lookups each
  // re-open + re-parse the same config.
  let config_path = bench_config_root + "/.git/config"
  b.bench(fn() {
    let v1 = read_config_value(
      bench_config_fs_small,
      config_path,
      "extensions",
      "objectformat",
    )
    let v2 = read_config_value(
      bench_config_fs_small,
      config_path,
      "extensions",
      "compatobjectformat",
    )
    let v3 = read_config_value(
      bench_config_fs_small,
      config_path,
      "extensions",
      "refstorage",
    )
    let v4 = read_config_value(
      bench_config_fs_small,
      config_path,
      "core",
      "repositoryformatversion",
    )
    b.keep((v1 is Some(_)) || (v2 is Some(_)) || (v3 is Some(_)) || (v4 is Some(_)))
  })
}

///|
test "bench read_config_value 4 keys on 100-remote config" (b : @bench.T) {
  let config_path = bench_config_root + "/.git/config"
  b.bench(fn() {
    let v1 = read_config_value(
      bench_config_fs_large,
      config_path,
      "extensions",
      "objectformat",
    )
    let v2 = read_config_value(
      bench_config_fs_large,
      config_path,
      "extensions",
      "compatobjectformat",
    )
    let v3 = read_config_value(
      bench_config_fs_large,
      config_path,
      "extensions",
      "refstorage",
    )
    let v4 = read_config_value(
      bench_config_fs_large,
      config_path,
      "core",
      "repositoryformatversion",
    )
    b.keep((v1 is Some(_)) || (v2 is Some(_)) || (v3 is Some(_)) || (v4 is Some(_)))
  })
}

///|
/// Counterpart that reads the config once and reuses the decoded
/// content across all four key lookups — the pattern used by
/// `repo_format_info` in `cmd/bit/helpers.mbt`. Should be roughly
/// the cost of one read + four (cheap) parses.
test "bench read_config_value_from_content 4 keys on 100-remote config" (b : @bench.T) {
  b.bench(fn() {
    let content = read_config_content(
      bench_config_fs_large,
      bench_config_root + "/.git",
    )
    let v1 = read_config_value_from_content(content, "extensions", "objectformat")
    let v2 = read_config_value_from_content(
      content,
      "extensions",
      "compatobjectformat",
    )
    let v3 = read_config_value_from_content(content, "extensions", "refstorage")
    let v4 = read_config_value_from_content(
      content,
      "core",
      "repositoryformatversion",
    )
    b.keep((v1 is Some(_)) || (v2 is Some(_)) || (v3 is Some(_)) || (v4 is Some(_)))
  })
}
