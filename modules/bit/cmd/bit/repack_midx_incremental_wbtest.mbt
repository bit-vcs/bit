///| End-to-end tests for `git repack --write-midx=incremental` (Git 2.55).
///
/// `--write-midx=incremental` must route to bit's incremental multi-pack-index
/// writer, producing a chain under objects/pack/multi-pack-index.d/ (a
/// `multi-pack-index-chain` file plus per-layer `.midx` files), whereas plain
/// `--write-midx` still writes a single monolithic `multi-pack-index` file.

///|
/// Build a tiny repo with a couple of commits and pack it into one packfile.
fn repack_midx_inc_setup_repo(root : String) -> Unit raise Error {
  let fs = OsFs::new()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  @bitrepo.init_repo(fs, root) catch { _ => () }
  for i in 0..<3 {
    @fs.write_string_to_file(root + "/f\{i}.txt", "content \{i}\n") catch {
      _ => ()
    }
  }
  @async.run_async_main(async fn() {
    @bitlib.add_paths_async(fs, fs, root, ["."]) catch { _ => () }
  })
  ignore(@bitlib.commit(
    fs, fs, root, "c0\n", "Test <t@example.com>", 1700000000L,
  )) catch {
    _ => ()
  }
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
/// Commit a new file, pack the new loose objects into their own packfile
/// (keeping existing packs), then add them to the incremental multi-pack-index.
fn midx_inc_commit_and_pack(root : String, tag : String) -> Unit {
  let fs = OsFs::new()
  @fs.write_string_to_file(root + "/file_\{tag}.txt", "data \{tag}\n") catch {
    _ => ()
  }
  @async.run_async_main(async fn() {
    @bitlib.add_paths_async(fs, fs, root, ["."]) catch { _ => () }
  })
  ignore(@bitlib.commit(
    fs,
    fs,
    root,
    "c\{tag}\n",
    "Test <t@example.com>",
    1700000000L,
  )) catch {
    _ => ()
  }
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", root, "repack", "-d"])
  })
  @async.run_async_main(async fn() {
    run_main_for_args(["bit", "-C", root, "repack", "--write-midx=incremental"])
  })
}

///|
test "midx repack config readers honor git config with clamping" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-midx-cfg-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  @bitrepo.init_repo(fs, root) catch { _ => () }
  let pack_dir = root + "/.git/objects/pack"
  @async.run_async_main(async fn() {
    run_main_for_args([
      "bit", "-C", root, "config", "repack.midxSplitFactor", "5",
    ])
  })
  @async.run_async_main(async fn() {
    run_main_for_args([
      "bit", "-C", root, "config", "repack.midxNewLayerThreshold", "20",
    ])
  })
  @test.assert_eq(midx_repack_split_factor(pack_dir), 5)
  @test.assert_eq(midx_repack_new_layer_threshold(pack_dir), 20)
  // Values below the documented minimums clamp (splitFactor>=2, threshold>=1).
  @async.run_async_main(async fn() {
    run_main_for_args([
      "bit", "-C", root, "config", "repack.midxSplitFactor", "1",
    ])
  })
  @async.run_async_main(async fn() {
    run_main_for_args([
      "bit", "-C", root, "config", "repack.midxNewLayerThreshold", "0",
    ])
  })
  @test.assert_eq(midx_repack_split_factor(pack_dir), 2)
  @test.assert_eq(midx_repack_new_layer_threshold(pack_dir), 1)
  cleanup_tree(fs, root)
}

///|
test "repack --write-midx=incremental keeps the chain compacted" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-midx-compact-" + get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  @bitrepo.init_repo(fs, root) catch { _ => () }
  let pack_dir = root + "/.git/objects/pack"
  // Five rounds, each creating a new pack + incremental midx write. With the
  // default new-layer threshold (8), each tiny layer folds into the tip, so
  // the chain stays compact instead of growing one layer per round.
  for r in 0..<5 {
    midx_inc_commit_and_pack(root, r.to_string())
  }
  let packs = midx_find_pack_files(fs, pack_dir)
  let layers = midx_read_chain_hashes(fs, pack_dir)
  // Multiple packs were created, but compaction kept the layer count small.
  assert_true(packs.length() >= 2)
  assert_true(layers.length() <= 2)
  // Every hash in the compacted chain resolves to a real layer file.
  for h in layers {
    assert_true(
      fs.is_file(
        pack_dir + "/multi-pack-index.d/multi-pack-index-" + h + ".midx",
      ),
    )
  }
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
