///|
test "object-db: reuses a decoded packed object without rereading its pack" {
  let fs = @bit.TestFs::new()
  ignore(init_repo(fs, "/repo")) catch {
    _ => ()
  }
  let obj = @bit.PackObject::new(
    @bit.ObjectType::Blob,
    Bytes::from_array([b'c', b'a', b'c', b'h', b'e']),
  )
  let (pack, _) = @pack.create_packfile_with_delta_stats_compression_reuse(
    [obj],
    @bit.PackDeltaMode::NoDelta,
    @bit.PackCompression::Default,
    false,
    0,
    1,
  )
  let packed_objects = @pack.parse_packfile(pack)
  let pack_base = "/repo/.git/objects/pack/pack-cache-test"
  let pack_path = pack_base + ".pack"
  fs.mkdir_p("/repo/.git/objects/pack")
  fs.write_file(pack_path, pack)
  @pack.write_pack_index_from_objects(
    fs,
    pack_base + ".idx",
    pack,
    packed_objects,
  )

  let db = ObjectDb::load(fs, "/repo/.git")
  let id = packed_objects[0].id
  assert_true(db.get(fs, id) is Some(_))
  db.pack_cache.clear()
  fs.remove_file(pack_path)

  assert_true(db.get(fs, id) is Some(_))
}

///|
test "object-db: caches a decoded delta base by pack location" {
  let fs = @bit.TestFs::new()
  ignore(init_repo(fs, "/repo")) catch {
    _ => ()
  }
  let base = Bytes::from_array(FixedArray::makei(1024, fn(_) { b'a' }))
  let child = Bytes::from_array(
    FixedArray::makei(1024, fn(i) { if i == 1023 { b'b' } else { b'a' } }),
  )
  let (pack, _) = @pack.create_packfile_with_delta_stats_compression_reuse(
    [
      @bit.PackObject::new(@bit.ObjectType::Blob, base),
      @bit.PackObject::new(@bit.ObjectType::Blob, child),
    ],
    @bit.PackDeltaMode::OfsDelta,
    @bit.PackCompression::Default,
    false,
    10,
    2,
  )
  let packed_objects = @pack.parse_packfile(pack)
  let mut delta_id : @bit.ObjectId? = None
  for obj in packed_objects {
    let (type_id, _, _) = @pack.decode_type_and_size_at(pack, obj.offset)
    if type_id == 6 || type_id == 7 {
      delta_id = Some(obj.id)
    }
  }
  guard delta_id is Some(id) else { fail("expected a delta entry") }

  let pack_base = "/repo/.git/objects/pack/pack-delta-cache-test"
  fs.mkdir_p("/repo/.git/objects/pack")
  fs.write_file(pack_base + ".pack", pack)
  @pack.write_pack_index_from_objects(
    fs,
    pack_base + ".idx",
    pack,
    packed_objects,
  )
  let db = ObjectDb::load(fs, "/repo/.git")

  assert_true(db.get(fs, id) is Some(_))
  assert_true(db.decoded_cache.length() >= 2)
}
