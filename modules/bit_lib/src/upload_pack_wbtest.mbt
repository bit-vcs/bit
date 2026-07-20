///|
test "upload-pack: generated pack uses OFS deltas" {
  let base = Bytes::from_array(FixedArray::makei(1024, fn(_) { b'a' }))
  let child = Bytes::from_array(
    FixedArray::makei(1024, fn(i) { if i == 1023 { b'b' } else { b'a' } }),
  )
  let pack = build_upload_packfile([
    @bit.PackObject::new(@bit.ObjectType::Blob, base),
    @bit.PackObject::new(@bit.ObjectType::Blob, child),
  ])
  let objects = @pack.parse_packfile(pack)
  let mut found_delta = false
  for obj in objects {
    let (type_id, _, _) = @pack.decode_type_and_size_at(pack, obj.offset)
    if type_id == 6 || type_id == 7 {
      found_delta = true
    }
  }
  assert_true(found_delta)
}

///|
test "upload-pack: have commit excludes its history from the pack" {
  let fs = @bit.TestFs::new()
  ignore(init_repo(fs, "/repo")) catch {
    _ => ()
  }
  fs.write_string("/repo/base.txt", "base\n")
  add_paths(fs, fs, "/repo", ["base.txt"])
  let base = commit(
    fs, fs, "/repo", "base\n", "Test <t@example.com>", 1700000000L,
  )
  fs.write_string("/repo/tip.txt", "tip\n")
  add_paths(fs, fs, "/repo", ["tip.txt"])
  let tip = commit(
    fs, fs, "/repo", "tip\n", "Test <t@example.com>", 1700000001L,
  )
  let response = upload_pack(fs, "/repo", {
    wants: [tip],
    haves: [base],
    capabilities: [],
    done: true,
    shallow: [],
    deepen: None,
  })
  let mut pack_start = -1
  for i in 0..<(response.length() - 3) {
    if response[i] == b'P' &&
      response[i + 1] == b'A' &&
      response[i + 2] == b'C' &&
      response[i + 3] == b'K' {
      pack_start = i
      break
    }
  }
  assert_true(pack_start >= 0)
  let pack = Bytes::from_array(
    FixedArray::makei(response.length() - pack_start, fn(i) {
      response[pack_start + i]
    }),
  )
  let packed_objects = @pack.parse_packfile(pack)
  let ids : Map[String, Bool] = Map([])
  for obj in packed_objects {
    ids[obj.id.to_hex()] = true
  }
  assert_true(ids.contains(tip.to_hex()))
  assert_true(!ids.contains(base.to_hex()))
}
