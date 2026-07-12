///| Benchmarks for ref enumeration.
///
/// Run with:
///   moon bench -p mizchi/bit/refs --target native -f bench_test.mbt
///
/// `list_refs_with_ids` is called on every fetch/clone (advertised
/// refs), every status that involves remotes, and every branch list.

///|
let bench_refs_root : String = "/bench_refs"

///|
fn setup_loose_refs_repo(branch_count : Int) -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  let git_dir = bench_refs_root + "/.git"
  fs.mkdir_p(git_dir + "/refs/heads")
  fs.mkdir_p(git_dir + "/refs/tags")
  fs.mkdir_p(git_dir + "/refs/remotes/origin")
  fs.write_string(git_dir + "/HEAD", "ref: refs/heads/main\n")
  let fake_id = "0123456789abcdef0123456789abcdef01234567"
  for i in 0..<branch_count {
    fs.write_string(git_dir + "/refs/heads/branch_\{i}", fake_id + "\n")
    fs.write_string(
      git_dir + "/refs/remotes/origin/branch_\{i}",
      fake_id + "\n",
    )
  }
  fs
}

///|
fn setup_packed_refs_repo(ref_count : Int) -> @bit.TestFs {
  let fs = @bit.TestFs::new()
  let git_dir = bench_refs_root + "/.git"
  fs.mkdir_p(git_dir + "/refs")
  fs.write_string(git_dir + "/HEAD", "ref: refs/heads/main\n")
  let sb = StringBuilder::new()
  sb.write_string("# pack-refs with: peeled fully-peeled sorted \n")
  let fake_id = "0123456789abcdef0123456789abcdef01234567"
  for i in 0..<ref_count {
    sb.write_string(fake_id + " refs/heads/branch_\{i}\n")
  }
  fs.write_string(git_dir + "/packed-refs", sb.to_string())
  fs
}

///|
let bench_loose_small : @bit.TestFs = setup_loose_refs_repo(20)

///|
let bench_loose_large : @bit.TestFs = setup_loose_refs_repo(200)

///|
let bench_packed_small : @bit.TestFs = setup_packed_refs_repo(50)

///|
let bench_packed_large : @bit.TestFs = setup_packed_refs_repo(2000)

///|
test "bench list_refs_with_ids loose 20 branches + 20 remotes" (b : @bench.T) {
  let git_dir = bench_refs_root + "/.git"
  b.bench(fn() {
    let refs = list_refs_with_ids(bench_loose_small, git_dir, None)
    b.keep(refs.length())
  })
}

///|
test "bench list_refs_with_ids loose 200 branches + 200 remotes" (b : @bench.T) {
  let git_dir = bench_refs_root + "/.git"
  b.bench(fn() {
    let refs = list_refs_with_ids(bench_loose_large, git_dir, None)
    b.keep(refs.length())
  })
}

///|
test "bench list_refs_with_ids loose 200+200 filtered refs/heads/" (
  b : @bench.T,
) {
  // Filter that excludes refs/remotes — exercises the new
  // subtree-pruning early exit.
  let git_dir = bench_refs_root + "/.git"
  b.bench(fn() {
    let refs = list_refs_with_ids(
      bench_loose_large,
      git_dir,
      Some("refs/heads/"),
    )
    b.keep(refs.length())
  })
}

///|
test "bench list_refs_with_ids packed 50 refs" (b : @bench.T) {
  let git_dir = bench_refs_root + "/.git"
  b.bench(fn() {
    let refs = list_refs_with_ids(bench_packed_small, git_dir, None)
    b.keep(refs.length())
  })
}

///|
test "bench list_refs_with_ids packed 2000 refs" (b : @bench.T) {
  let git_dir = bench_refs_root + "/.git"
  b.bench(fn() {
    let refs = list_refs_with_ids(bench_packed_large, git_dir, None)
    b.keep(refs.length())
  })
}

///|
test "bench list_refs_with_ids packed 2000 filtered by prefix" (b : @bench.T) {
  let git_dir = bench_refs_root + "/.git"
  b.bench(fn() {
    let refs = list_refs_with_ids(
      bench_packed_large,
      git_dir,
      Some("refs/heads/"),
    )
    b.keep(refs.length())
  })
}
