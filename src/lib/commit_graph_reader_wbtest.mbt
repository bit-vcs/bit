///| Tests for commit-graph binary reader

///|
test "CommitGraphFile::load returns None for missing file" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/objects/info")
  let result = CommitGraphFile::load(fs, "/repo/.git")
  assert_true(result is None)
}

///|
test "CommitGraphFile::find_commit returns -1 for empty graph" {
  let graph = build_test_commit_graph([])
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/objects/info")
  fs.write_file("/repo/.git/objects/info/commit-graph", graph)
  let cg = CommitGraphFile::load(fs, "/repo/.git")
  assert_true(cg is Some(_))
  let g = cg.unwrap()
  assert_eq(g.num_commits, 0)
  let id = @bit.ObjectId::from_hex("da39a3ee5e6b4b0d3255bfef95601890afd80709")
  assert_eq(g.find_commit(id), -1)
}

///|
test "CommitGraphFile with one commit can find and read it" {
  let oid = @bit.ObjectId::from_hex("0123456789abcdef0123456789abcdef01234567")
  let tree = @bit.ObjectId::from_hex("abcdef0123456789abcdef0123456789abcdef01")
  let graph = build_test_commit_graph([
    TestCommitEntry::new(oid, tree, [], 1700000000L),
  ])
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/objects/info")
  fs.write_file("/repo/.git/objects/info/commit-graph", graph)
  let g = CommitGraphFile::load(fs, "/repo/.git").unwrap()
  assert_eq(g.num_commits, 1)
  let pos = g.find_commit(oid)
  assert_true(pos >= 0)
  let (read_tree, parents, timestamp) = g.read_commit(pos)
  assert_eq(read_tree, tree)
  assert_eq(parents.length(), 0)
  assert_eq(timestamp, 1700000000L)
}

///|
test "CommitGraphFile with parent chain" {
  let oid_a = @bit.ObjectId::from_hex(
    "1111111111111111111111111111111111111111",
  )
  let oid_b = @bit.ObjectId::from_hex(
    "2222222222222222222222222222222222222222",
  )
  let tree = @bit.ObjectId::from_hex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  let graph = build_test_commit_graph([
    TestCommitEntry::new(oid_a, tree, [], 100L),
    TestCommitEntry::new(oid_b, tree, [oid_a], 200L),
  ])
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/objects/info")
  fs.write_file("/repo/.git/objects/info/commit-graph", graph)
  let g = CommitGraphFile::load(fs, "/repo/.git").unwrap()
  assert_eq(g.num_commits, 2)
  let pos_b = g.find_commit(oid_b)
  assert_true(pos_b >= 0)
  let (_, parents, ts) = g.read_commit(pos_b)
  assert_eq(parents.length(), 1)
  assert_eq(parents[0], oid_a)
  assert_eq(ts, 200L)
}

///|
test "synthesize_commit_object produces parseable commit" {
  let oid = @bit.ObjectId::from_hex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  let tree = @bit.ObjectId::from_hex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
  let graph = build_test_commit_graph([
    TestCommitEntry::new(oid, tree, [], 1700000000L),
  ])
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git/objects/info")
  fs.write_file("/repo/.git/objects/info/commit-graph", graph)
  let g = CommitGraphFile::load(fs, "/repo/.git").unwrap()
  let pos = g.find_commit(oid)
  let obj = g.synthesize_commit_object(pos, oid)
  assert_eq(obj.obj_type, @bit.ObjectType::Commit)
  let text = @utf8.decode_lossy(obj.data[:])
  assert_true(text.contains("tree bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))
  assert_true(text.contains("1700000000"))
}

// -- Test helpers --

///|
struct TestCommitEntry {
  oid : @bit.ObjectId
  tree : @bit.ObjectId
  parents : Array[@bit.ObjectId]
  timestamp : Int64
}

///|
fn TestCommitEntry::new(
  oid : @bit.ObjectId,
  tree : @bit.ObjectId,
  parents : Array[@bit.ObjectId],
  timestamp : Int64,
) -> TestCommitEntry {
  { oid, tree, parents, timestamp }
}

///|
fn build_test_commit_graph(entries : Array[TestCommitEntry]) -> Bytes {
  let hash_size = 20
  let num = entries.length()
  entries.sort_by(fn(a, b) {
    for i = 0; i < hash_size; i = i + 1 {
      let ab = a.oid.bytes[i].to_int()
      let bb = b.oid.bytes[i].to_int()
      if ab < bb {
        return -1
      }
      if ab > bb {
        return 1
      }
    }
    0
  })
  let pos_map : Map[String, Int] = {}
  for i = 0; i < num; i = i + 1 {
    pos_map[entries[i].oid.to_hex()] = i
  }
  let buf : Array[Byte] = []
  let num_chunks = 3
  buf.push(b'\x43')
  buf.push(b'\x47')
  buf.push(b'\x50')
  buf.push(b'\x48')
  buf.push(b'\x01')
  buf.push(b'\x01')
  buf.push(num_chunks.to_byte())
  buf.push(b'\x00')
  let toc_start = 8
  let oidf_start = toc_start + (num_chunks + 1) * 12
  let oidl_start = oidf_start + 256 * 4
  let cdat_start = oidl_start + num * hash_size
  let end_offset = cdat_start + num * (hash_size + 16)
  tcg_write_u32(buf, 0x4f494446)
  tcg_write_u32(buf, 0)
  tcg_write_u32(buf, oidf_start)
  tcg_write_u32(buf, 0x4f49444c)
  tcg_write_u32(buf, 0)
  tcg_write_u32(buf, oidl_start)
  tcg_write_u32(buf, 0x43444154)
  tcg_write_u32(buf, 0)
  tcg_write_u32(buf, cdat_start)
  tcg_write_u32(buf, 0)
  tcg_write_u32(buf, 0)
  tcg_write_u32(buf, end_offset)
  for i = 0; i < 256; i = i + 1 {
    let mut count = 0
    for entry in entries {
      if entry.oid.bytes[0].to_int() <= i {
        count += 1
      }
    }
    tcg_write_u32(buf, count)
  }
  for entry in entries {
    for b in entry.oid.bytes {
      buf.push(b)
    }
  }
  for entry in entries {
    for b in entry.tree.bytes {
      buf.push(b)
    }
    if entry.parents.length() > 0 {
      tcg_write_u32(
        buf,
        pos_map.get(entry.parents[0].to_hex()).unwrap_or(0x70000000),
      )
    } else {
      tcg_write_u32(buf, 0x70000000)
    }
    if entry.parents.length() > 1 {
      tcg_write_u32(
        buf,
        pos_map.get(entry.parents[1].to_hex()).unwrap_or(0x70000000),
      )
    } else {
      tcg_write_u32(buf, 0x70000000)
    }
    let date_hi = ((entry.timestamp >> 32) & 0x3L).to_int()
    tcg_write_u32(buf, (1 << 2) | date_hi)
    tcg_write_u32(buf, (entry.timestamp & 0xffffffffL).to_int())
  }
  Bytes::from_array(buf)
}

///|
fn tcg_write_u32(buf : Array[Byte], value : Int) -> Unit {
  buf.push(((value >> 24) & 0xff).to_byte())
  buf.push(((value >> 16) & 0xff).to_byte())
  buf.push(((value >> 8) & 0xff).to_byte())
  buf.push((value & 0xff).to_byte())
}
