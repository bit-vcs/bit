///| End-to-end tests for `git repack --write-midx=incremental` (Git 2.55).
///
/// `--write-midx=incremental` must route to bit's incremental multi-pack-index
/// writer, producing a chain under objects/pack/multi-pack-index.d/ (a
/// `multi-pack-index-chain` file plus per-layer `.midx` files), whereas plain
/// `--write-midx` still writes a single monolithic `multi-pack-index` file.

///| Build a tiny repo with a couple of commits and pack it into one packfile.
fn repack_midx_inc_setup_repo(root : String) -> Unit raise Error {
  let fs = OsFs::new()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  ignore(try? @bitrepo.init_repo(fs, root))
  for i in 0..<3 {
    @fs.write_string_to_file(root + "/f\{i}.txt", "content \{i}\n") catch {
      _ => ()
    }
  }
  @async.run_async_main(async fn() {
    ignore(try? @bitlib.add_paths_async(fs, fs, root, ["."]))
  })
  ignore(
    try? @bitlib.commit(
      fs, fs, root, "c0\n", "Test <t@example.com>", 1700000000L,
    ),
  )
  // Pack the loose objects into a single packfile.
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", root, "repack", "-a", "-d"])
  })
}

///|
test "repack --write-midx=incremental writes a midx chain" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-repack-midx-inc-" +
    get_current_timestamp().to_string()
  repack_midx_inc_setup_repo(root)
  let pack_dir = root + "/.git/objects/pack"
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", root, "repack", "--write-midx=incremental"])
  })
  // The incremental writer produces the chain directory + chain file, not the
  // monolithic single-file index.
  assert_true(
    fs.is_file(pack_dir + "/multi-pack-index.d/multi-pack-index-chain"),
  )
  assert_true(!fs.is_file(pack_dir + "/multi-pack-index"))
  cleanup_tree(fs, root)
}

///|
test "repack --write-midx (plain) writes a monolithic index" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-repack-midx-mono-" +
    get_current_timestamp().to_string()
  repack_midx_inc_setup_repo(root)
  let pack_dir = root + "/.git/objects/pack"
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", root, "repack", "--write-midx"])
  })
  assert_true(fs.is_file(pack_dir + "/multi-pack-index"))
  assert_true(!fs.is_dir(pack_dir + "/multi-pack-index.d"))
  cleanup_tree(fs, root)
}
