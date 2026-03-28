///| Commit-graph file writer
///
/// Format: objects/info/commit-graph
///   - 4 bytes: signature "CGPH" (0x43475048)
///   - 1 byte: version = 1
///   - 1 byte: hash version (1=SHA-1, 2=SHA-256)
///   - 1 byte: number of chunks
///   - 1 byte: number of base graphs = 0
///   - Chunk table of contents (N+1 entries × 12 bytes each)
///   - OIDF chunk: 256 × 4-byte fanout
///   - OIDL chunk: N × hash_size sorted OIDs
///   - CDAT chunk: N × (hash_size + 16) commit data
///   - EDGE chunk: extra parent edges for octopus merges
///   - SHA-1 checksum trailer (20 bytes)

///|
priv struct CgraphCommitEntry {
  oid : @bitcore.ObjectId
  tree : @bitcore.ObjectId
  parents : Array[@bitcore.ObjectId]
  commit_timestamp : Int64
}

///|
fn cgraph_compare_oid_bytes(
  a : FixedArray[Byte],
  b : FixedArray[Byte],
  len : Int,
) -> Int {
  for i in 0..<len {
    let av = a[i].to_int()
    let bv = b[i].to_int()
    if av < bv {
      return -1
    }
    if av > bv {
      return 1
    }
  }
  0
}

///|
fn cgraph_extract_committer_timestamp(data : Bytes) -> Int64 {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("committer ") {
      let rest = String::unsafe_substring(line, start=10, end=line.length())
      // Find '>' to locate end of email
      let mut gt_pos = -1
      for ci in 0..<rest.length() {
        if rest[ci] == '>' {
          gt_pos = ci
        }
      }
      if gt_pos >= 0 && gt_pos + 2 < rest.length() {
        let after_email = String::unsafe_substring(
          rest,
          start=gt_pos + 2,
          end=rest.length(),
        )
        // "timestamp tz"
        for part_view in after_email.split(" ") {
          let part = part_view.to_string()
          if part.length() > 0 {
            let ts = @strconv.parse_int64(part) catch { _ => continue }
            return ts
          }
        }
      }
    }
  }
  0L
}

///|
/// Write a commit-graph file for all reachable commits in the repository.
async fn write_commit_graph(
  fs : OsFs,
  git_dir : String,
  reachable_only : Bool,
) -> Unit raise Error {
  let rfs : &@bitcore.RepoFileSystem = fs
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  // Collect commit OIDs
  let commit_ids : Array[@bitcore.ObjectId] = []
  if reachable_only {
    // Walk from all refs
    let refs = @bitlib.list_refs_with_ids(rfs, git_dir, Some("refs/"))
    let tip_ids : Array[@bitcore.ObjectId] = []
    for _, id in refs {
      tip_ids.push(id)
    }
    // Also add HEAD
    let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD") catch { _ => None }
    match head {
      Some(id) => tip_ids.push(id)
      None => ()
    }
    let seen : Map[String, Bool] = {}
    for tip_id in tip_ids {
      cgraph_walk_commits(db, rfs, tip_id, seen, commit_ids)
    }
  } else {
    // Enumerate all commits from pack indexes + loose
    for pack in db.packs {
      for hex in pack.ids {
        let oid = @bitcore.ObjectId::from_hex(hex)
        let obj = db.get(rfs, oid) catch { _ => None }
        match obj {
          Some(o) =>
            if o.obj_type == @bitcore.ObjectType::Commit {
              commit_ids.push(oid)
            }
          None => ()
        }
      }
    }
    // Also check loose objects
    let loose_dir = git_dir + "/objects"
    cgraph_collect_loose_commits(rfs, db, loose_dir, commit_ids)
  }
  if commit_ids.length() == 0 {
    return
  }
  // Build commit entries with parsed data
  let hash_size = cgraph_repo_hash_size(rfs, git_dir)
  let entries : Array[CgraphCommitEntry] = []
  let seen_hex : Map[String, Bool] = {}
  for cid in commit_ids {
    let hex = cid.to_hex()
    if seen_hex.contains(hex) {
      continue
    }
    seen_hex[hex] = true
    let obj = db.get(rfs, cid) catch { _ => None }
    match obj {
      Some(o) =>
        if o.obj_type == @bitcore.ObjectType::Commit {
          let info = @bitcore.parse_commit(o.data) catch { _ => continue }
          let ts = cgraph_extract_committer_timestamp(o.data)
          entries.push({ oid: cid, tree: info.tree, parents: info.parents, commit_timestamp: ts })
        }
      None => ()
    }
  }
  if entries.length() == 0 {
    return
  }
  // Sort entries by OID (lexicographic byte order)
  entries.sort_by(fn(a, b) {
    cgraph_compare_oid_bytes(a.oid.bytes, b.oid.bytes, hash_size)
  })
  // Build position map
  let pos_map : Map[String, Int] = {}
  for i, entry in entries {
    pos_map[entry.oid.to_hex()] = i
  }
  let num = entries.length()
  // Check if we need EDGE chunk (any commit with >2 parents)
  let mut needs_edge = false
  for entry in entries {
    if entry.parents.length() > 2 {
      needs_edge = true
      break
    }
  }
  // Calculate chunk layout
  let num_chunks = if needs_edge { 4 } else { 3 }
  let toc_start = 8
  let oidf_start = toc_start + (num_chunks + 1) * 12
  let oidl_start = oidf_start + 256 * 4
  let cdat_start = oidl_start + num * hash_size
  // Calculate EDGE chunk size if needed
  let mut edge_entry_count = 0
  if needs_edge {
    for entry in entries {
      if entry.parents.length() > 2 {
        // parents[2..] go into EDGE chunk, each as 4 bytes, last with terminator bit
        edge_entry_count += entry.parents.length() - 1 // parent2 onwards
      }
    }
  }
  let edge_start = cdat_start + num * (hash_size + 16)
  let end_offset = edge_start + edge_entry_count * 4
  // Build output buffer
  let buf : Array[Byte] = []
  // Header
  buf.push(b'\x43') // C
  buf.push(b'\x47') // G
  buf.push(b'\x50') // P
  buf.push(b'\x48') // H
  buf.push(b'\x01') // version 1
  buf.push((if hash_size == 32 { 2 } else { 1 }).to_byte()) // hash version
  buf.push(num_chunks.to_byte()) // number of chunks
  buf.push(b'\x00') // number of base graphs = 0
  // Chunk TOC
  // OIDF
  midx_push_u32(buf, 0x4f494446)
  midx_push_u32(buf, 0)
  midx_push_u32(buf, oidf_start)
  // OIDL
  midx_push_u32(buf, 0x4f49444c)
  midx_push_u32(buf, 0)
  midx_push_u32(buf, oidl_start)
  // CDAT
  midx_push_u32(buf, 0x43444154)
  midx_push_u32(buf, 0)
  midx_push_u32(buf, cdat_start)
  // EDGE (if needed)
  if needs_edge {
    midx_push_u32(buf, 0x45444745)
    midx_push_u32(buf, 0)
    midx_push_u32(buf, edge_start)
  }
  // Terminator
  midx_push_u32(buf, 0)
  midx_push_u32(buf, 0)
  midx_push_u32(buf, end_offset)
  // OIDF: 256-entry fanout table (histogram approach, O(N))
  let fanout : Array[Int] = Array::make(256, 0)
  for entry in entries {
    fanout[entry.oid.bytes[0].to_int()] += 1
  }
  // Convert counts to cumulative sums
  for i in 1..<256 {
    fanout[i] += fanout[i - 1]
  }
  for i in 0..<256 {
    midx_push_u32(buf, fanout[i])
  }
  // OIDL: sorted OIDs
  for entry in entries {
    for i in 0..<hash_size {
      buf.push(entry.oid.bytes[i])
    }
  }
  // CDAT: commit data entries
  // Track edge positions for octopus merges
  let mut edge_pos = 0
  for entry in entries {
    // Tree OID
    for i in 0..<hash_size {
      buf.push(entry.tree.bytes[i])
    }
    // Parent 1
    if entry.parents.length() > 0 {
      let p1_pos = pos_map.get(entry.parents[0].to_hex()).unwrap_or(0x70000000)
      midx_push_u32(buf, p1_pos)
    } else {
      midx_push_u32(buf, 0x70000000)
    }
    // Parent 2
    if entry.parents.length() == 0 || entry.parents.length() == 1 {
      midx_push_u32(buf, 0x70000000)
    } else if entry.parents.length() == 2 {
      let p2_pos = pos_map.get(entry.parents[1].to_hex()).unwrap_or(0x70000000)
      midx_push_u32(buf, p2_pos)
    } else {
      // Octopus merge: point to EDGE chunk with high bit set
      midx_push_u32(buf, edge_pos | 0x80000000)
      edge_pos += entry.parents.length() - 1
    }
    // Generation number + date
    // Use generation = 1 (simple; could compute topological generation in future)
    let date_hi = ((entry.commit_timestamp >> 32) & 0x3L).to_int()
    let gen = 1
    midx_push_u32(buf, (gen << 2) | date_hi)
    midx_push_u32(buf, (entry.commit_timestamp & 0xffffffffL).to_int())
  }
  // EDGE chunk (if needed)
  if needs_edge {
    for entry in entries {
      if entry.parents.length() > 2 {
        // Write parents[1..] into EDGE chunk
        for pi in 1..<entry.parents.length() {
          let p_pos = pos_map
            .get(entry.parents[pi].to_hex())
            .unwrap_or(0x70000000)
          if pi == entry.parents.length() - 1 {
            // Last entry: set terminator bit (0x80000000)
            midx_push_u32(buf, p_pos | 0x80000000)
          } else {
            midx_push_u32(buf, p_pos)
          }
        }
      }
    }
  }
  // SHA-1 checksum trailer
  let body_arr = FixedArray::makei(buf.length(), fn(i) { buf[i] })
  let trailer = @bitcore.sha1(Bytes::from_array(body_arr))
  for b in trailer.bytes {
    buf.push(b)
  }
  // Write file
  let info_dir = git_dir + "/objects/info"
  if not(rfs.is_dir(info_dir)) {
    fs.mkdir_p(info_dir)
  }
  let graph_path = info_dir + "/commit-graph"
  fs.write_file(
    graph_path,
    Bytes::from_array(FixedArray::makei(buf.length(), fn(i) { buf[i] })),
  )
}

///|
fn cgraph_walk_commits(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
  seen : Map[String, Bool],
  out : Array[@bitcore.ObjectId],
) -> Unit {
  let stack : Array[@bitcore.ObjectId] = [commit_id]
  while stack.length() > 0 {
    let id = stack.pop().unwrap()
    let hex = id.to_hex()
    if seen.contains(hex) {
      continue
    }
    seen[hex] = true
    let obj = db.get(rfs, id) catch { _ => None }
    match obj {
      Some(o) =>
        if o.obj_type == @bitcore.ObjectType::Commit {
          out.push(id)
          let info = @bitcore.parse_commit(o.data) catch { _ => continue }
          for parent in info.parents {
            if not(seen.contains(parent.to_hex())) {
              stack.push(parent)
            }
          }
        }
      None => ()
    }
  }
}

///|
fn cgraph_collect_loose_commits(
  rfs : &@bitcore.RepoFileSystem,
  db : @bitlib.ObjectDb,
  objects_dir : String,
  out : Array[@bitcore.ObjectId],
) -> Unit raise Error {
  // Scan xx/ directories for loose objects
  let entries = rfs.readdir(objects_dir) catch { _ => return }
  for name in entries {
    if name.length() == 2 {
      let subdir = objects_dir + "/" + name
      let files = rfs.readdir(subdir) catch { _ => continue }
      for fname in files {
        let hex = name + fname
        if hex.length() == 40 || hex.length() == 64 {
          let oid = @bitcore.ObjectId::from_hex(hex)
          let obj = db.get(rfs, oid) catch { _ => None }
          match obj {
            Some(o) =>
              if o.obj_type == @bitcore.ObjectType::Commit {
                out.push(oid)
              }
            None => ()
          }
        }
      }
    }
  }
}

///|
fn cgraph_repo_hash_size(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
) -> Int {
  match
    @bitlib.read_config_value(
      rfs,
      git_dir + "/config",
      "extensions",
      "objectformat",
    ) {
    Some(value) => if value.to_lower() == "sha256" { 32 } else { 20 }
    None => 20
  }
}
