///| Benchmarks for git-config parsing.
///
/// Run with:
///   moon bench -p mizchi/bit/config_parse --target native -f bench_test.mbt
///
/// Every repository open re-reads .git/config; large repos and global
/// gitconfig files can run hundreds of lines.

///|
let bench_small_config : String =
  #|[core]
  #|	repositoryformatversion = 0
  #|	filemode = true
  #|	bare = false
  #|	logallrefupdates = true
  #|[remote "origin"]
  #|	url = https://github.com/example/repo.git
  #|	fetch = +refs/heads/*:refs/remotes/origin/*
  #|[branch "main"]
  #|	remote = origin
  #|	merge = refs/heads/main

///|
/// Synthesize a config with many remotes — realistic upper bound for
/// a repo with lots of upstreams (e.g. an aggregator).
fn bench_make_large_config(num_remotes : Int) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n",
  )
  for i in 0..<num_remotes {
    sb.write_string("[remote \"r\{i}\"]\n")
    sb.write_string("\turl = https://example.com/repo\{i}.git\n")
    sb.write_string("\tfetch = +refs/heads/*:refs/remotes/r\{i}/*\n")
  }
  sb.to_string()
}

///|
let bench_large_config : String = bench_make_large_config(100)

///|
test "bench config_lines_from_content small" (b : @bench.T) {
  b.bench(fn() {
    let lines = config_lines_from_content(bench_small_config)
    b.keep(lines.length())
  })
}

///|
test "bench config_lines_from_content 100 remotes" (b : @bench.T) {
  b.bench(fn() {
    let lines = config_lines_from_content(bench_large_config)
    b.keep(lines.length())
  })
}

///|
test "bench get_config_value_from_content small" (b : @bench.T) {
  b.bench(fn() {
    let v = get_config_value_from_content(
      bench_small_config, "remote.origin.url", None, false,
    )
    b.keep(v is Some(_))
  })
}

///|
test "bench get_config_value_from_content miss" (b : @bench.T) {
  // Worst case: scan the entire file without finding the key.
  b.bench(fn() {
    let v = get_config_value_from_content(
      bench_large_config, "branch.does-not-exist.remote", None, false,
    )
    b.keep(v is Some(_))
  })
}

///|
test "bench get_all_config_values_from_content remote.*.url" (b : @bench.T) {
  b.bench(fn() {
    let values = get_all_config_values_from_content(
      bench_large_config, "remote.url", None, false,
    )
    b.keep(values.length())
  })
}

///|
test "bench parse_section_header_line subsection" (b : @bench.T) {
  let line = "[submodule \"vendored/library/path\"]"
  b.bench(fn() {
    let parsed = parse_section_header_line(line)
    b.keep(parsed is Some(_))
  })
}

///|
test "bench parse_config_key dotted" (b : @bench.T) {
  let key = "remote.origin.fetch"
  b.bench(fn() {
    let parsed = parse_config_key(key)
    b.keep(parsed is Some(_))
  })
}

///|
test "bench parse_bool_keyword_value" (b : @bench.T) {
  b.bench(fn() {
    let v = parse_bool_keyword_value("true")
    b.keep(v is Some(_))
  })
}

///|
test "bench config_parse_size_value 1M" (b : @bench.T) {
  b.bench(fn() {
    let v = config_parse_size_value("1m")
    b.keep(v is Some(_))
  })
}
