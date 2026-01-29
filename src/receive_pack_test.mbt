///| Tests for receive-pack

///|
fn build_receive_request(
  old_id : ObjectId,
  new_id : ObjectId,
  refname : String,
  pack : Bytes,
) -> Bytes {
  let out : Array[Byte] = []
  let cmd = build_ref_update(old_id, new_id, refname, "report-status")
  for b in pktline_encode(cmd) {
    out.push(b)
  }
  for b in pktline_flush() {
    out.push(b)
  }
  for b in pack {
    out.push(b)
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(i) { out[i] }))
}

///|
test "receive-pack: push to empty repo" {
  let fs = TestFs::new()
  ignore(try? init_repo(fs, "/src"))
  ignore(try? init_repo(fs, "/dst"))
  fs.write_string("/src/a.txt", "hello\n")
  add_paths(fs, fs, "/src", ["a.txt"])
  let commit_id = commit(
    fs, fs, "/src", "msg\n", "Test <t@example.com>", 1700000000L,
  )
  let db = ObjectDb::load(fs, "/src/.git")
  let objects = collect_reachable_objects(db, fs, commit_id)
  let pack = create_packfile(objects)
  let req = build_receive_request(
    ObjectId::zero(),
    commit_id,
    "refs/heads/main",
    pack,
  )
  ignore(receive_pack(fs, fs, "/dst", req))
  match resolve_ref(fs, "/dst/.git", "refs/heads/main") {
    None => assert_true(false)
    Some(id) => assert_true(id == commit_id)
  }
  let pack_dir = "/dst/.git/objects/pack"
  assert_true(fs.is_dir(pack_dir))
  let files = fs.readdir(pack_dir)
  assert_true(files.length() > 0)
}
