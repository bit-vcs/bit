///| Git fsck: connectivity check and object integrity verification (pure logic)

///|
pub struct FsckResult {
  errors : Int
  reachable : Map[String, Bool]
  missing : Map[String, Bool]
  root_commits : Array[String]
  tag_objects : Array[String]
}

///|
/// BFS connectivity walk from multiple tips.
/// Returns reachable set, missing set, root commits, tag objects, and error count.
/// This is the pure core of fsck — no filesystem access, no stderr output.
pub fn fsck_connectivity_check(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  tips : Array[@bit.ObjectId],
  collect_extra? : Bool = false,
) -> FsckResult {
  let reachable : Map[String, Bool] = {}
  let missing : Map[String, Bool] = {}
  let root_commits : Array[String] = []
  let tag_objects : Array[String] = []
  let mut errors = 0
  let queue : Array[@bit.ObjectId] = []
  for tip in tips {
    queue.push(tip)
  }
  let mut cursor = 0
  while cursor < queue.length() {
    let current = queue[cursor]
    cursor += 1
    let hex = current.to_hex()
    if reachable.contains(hex) {
      continue
    }
    reachable[hex] = true
    let obj = db.get(fs, current) catch {
      _ => {
        if !(missing.contains(hex)) {
          missing[hex] = true
          errors += 1
        }
        continue
      }
    }
    match obj {
      None =>
        if !(missing.contains(hex)) {
          missing[hex] = true
          errors += 1
        }
      Some(o) =>
        match o.obj_type {
          @bit.ObjectType::Commit => {
            let info = @bit.parse_commit(o.data) catch {
              _ => {
                errors += 1
                continue
              }
            }
            if collect_extra && info.parents.length() == 0 {
              root_commits.push(hex)
            }
            let tree_hex = info.tree.to_hex()
            if !(reachable.contains(tree_hex)) {
              queue.push(info.tree)
            }
            for parent in info.parents {
              let phex = parent.to_hex()
              if !(reachable.contains(phex)) {
                queue.push(parent)
              }
            }
          }
          @bit.ObjectType::Tree => {
            let entries = @bit.parse_tree(o.data) catch {
              _ => {
                errors += 1
                continue
              }
            }
            for entry in entries {
              let ehex = entry.id.to_hex()
              if !(reachable.contains(ehex)) {
                queue.push(entry.id)
              }
            }
          }
          @bit.ObjectType::Tag => {
            if collect_extra {
              tag_objects.push(hex)
            }
            fsck_walk_tag(o.data, reachable, queue)
          }
          @bit.ObjectType::Blob => ()
        }
    }
  }
  { errors, reachable, missing, root_commits, tag_objects }
}

///|
fn fsck_walk_tag(
  data : Bytes,
  reachable : Map[String, Bool],
  queue : Array[@bit.ObjectId],
) -> Unit {
  let text = @utf8.decode_lossy(data[:])
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("object ") {
      let target_hex = String::unsafe_substring(
        line,
        start=7,
        end=line.length(),
      )
      let target = @bit.ObjectId::from_hex(target_hex) catch { _ => return }
      if !(reachable.contains(target.to_hex())) {
        queue.push(target)
      }
      break
    }
  }
}

///|
/// Enumerate all object hex IDs from ObjectDb (loose + packed).
pub fn fsck_enumerate_objects(db : ObjectDb) -> Array[String] {
  let all : Array[String] = []
  let seen : Map[String, Bool] = {}
  for hex, _ in db.loose_paths {
    if !(seen.contains(hex)) {
      seen[hex] = true
      all.push(hex)
    }
  }
  for pack in db.packs {
    for id in pack.ids {
      if !(seen.contains(id)) {
        seen[id] = true
        all.push(id)
      }
    }
  }
  all
}

///|
/// Get the type name of an object by hex ID.
pub fn fsck_object_type(
  db : ObjectDb,
  fs : &@bit.RepoFileSystem,
  hex : String,
) -> String {
  let id = @bit.ObjectId::from_hex(hex) catch { _ => return "blob" }
  let obj = db.get(fs, id) catch { _ => return "blob" }
  match obj {
    None => "blob"
    Some(o) => o.obj_type.to_string()
  }
}

///|
/// Verify a single loose object's hash. Returns true if valid.
pub fn fsck_verify_loose_hash(raw : Bytes, expected_hex : String) -> Bool {
  let computed = @bit.sha1(raw)
  computed.to_hex() == expected_hex
}
