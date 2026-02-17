///| Differential tree construction for snapshots

///|
priv struct TreeNode {
  blob_id : @bit.ObjectId?
  mode : Int
  children : Map[String, TreeNode]
  base_tree_id : @bit.ObjectId?
  mut loaded : Bool
  mut dirty : Bool
}

///|
fn TreeNode::new_file(id : @bit.ObjectId, mode : Int) -> TreeNode {
  {
    blob_id: Some(id),
    mode,
    children: {},
    base_tree_id: None,
    loaded: true,
    dirty: false,
  }
}

///|
fn TreeNode::new_dir() -> TreeNode {
  {
    blob_id: None,
    mode: 0o040000,
    children: {},
    base_tree_id: None,
    loaded: true,
    dirty: false,
  }
}

///|
fn TreeNode::new_base_dir(id : @bit.ObjectId) -> TreeNode {
  {
    blob_id: None,
    mode: 0o040000,
    children: {},
    base_tree_id: Some(id),
    loaded: false,
    dirty: false,
  }
}

///|
pub fn build_tree_from_working(
  backing_fs : &@bit.FileSystem,
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  base_tree : @bit.ObjectId,
  working : WorkingLayer,
) -> @bit.ObjectId raise @bit.GitError {
  let (root, db) = if base_tree == @bit.ObjectId::zero() {
    (TreeNode::new_dir(), None)
  } else {
    (
      TreeNode::new_base_dir(base_tree),
      Some(@lib.ObjectDb::load_lazy(rfs, git_dir)),
    )
  }
  for item in working.deleted.to_array() {
    let (path, _) = item
    delete_from_tree(db, rfs, root, path)
  }
  for item in working.files.to_array() {
    let (path, content) = item
    let blob_id = @lib.write_loose_object(
      backing_fs,
      git_dir,
      @bit.ObjectType::Blob,
      content,
    )
    insert_into_tree(db, rfs, root, path, blob_id, 0o100644)
  }
  write_tree_recursive(backing_fs, git_dir, root)
}

///|
fn ensure_dir_loaded(
  db_opt : @lib.ObjectDb?,
  rfs : &@bit.RepoFileSystem,
  node : TreeNode,
) -> Unit raise @bit.GitError {
  guard node.blob_id is None else { return }
  if node.loaded {
    return
  }
  let tree_id = match node.base_tree_id {
    Some(id) => id
    None => {
      node.loaded = true
      return
    }
  }
  let db = match db_opt {
    Some(v) => v
    None =>
      raise @bit.GitError::InvalidObject(
        "Tree load requested without object database: \{tree_id}",
      )
  }
  let obj = db.get(rfs, tree_id)
  guard obj is Some(o) else {
    raise @bit.GitError::InvalidObject("Tree not found: \{tree_id}")
  }
  if o.obj_type != @bit.ObjectType::Tree {
    raise @bit.GitError::InvalidObject("Not a tree: \{tree_id}")
  }
  let entries = @bit.parse_tree(o.data)
  for entry in entries {
    if is_tree_mode(entry.mode) {
      node.children[entry.name] = TreeNode::new_base_dir(entry.id)
    } else {
      let mode = parse_octal(entry.mode)
      node.children[entry.name] = TreeNode::new_file(entry.id, mode)
    }
  }
  node.loaded = true
}

///|
fn load_tree_structure(
  rfs : &@bit.RepoFileSystem,
  git_dir : String,
  tree_id : @bit.ObjectId,
) -> TreeNode raise @bit.GitError {
  let root = TreeNode::new_dir()
  if tree_id == @bit.ObjectId::zero() {
    return root
  }
  let db = @lib.ObjectDb::load_lazy(rfs, git_dir)
  load_tree_recursive(db, rfs, tree_id, root)
  root
}

///|
fn load_tree_recursive(
  db : @lib.ObjectDb,
  rfs : &@bit.RepoFileSystem,
  tree_id : @bit.ObjectId,
  node : TreeNode,
) -> Unit raise @bit.GitError {
  let obj = db.get(rfs, tree_id)
  guard obj is Some(o) else {
    raise @bit.GitError::InvalidObject("Tree not found: \{tree_id}")
  }
  if o.obj_type != @bit.ObjectType::Tree {
    raise @bit.GitError::InvalidObject("Not a tree: \{tree_id}")
  }
  let entries = @bit.parse_tree(o.data)
  for entry in entries {
    if is_tree_mode(entry.mode) {
      let child = TreeNode::new_dir()
      load_tree_recursive(db, rfs, entry.id, child)
      node.children[entry.name] = child
    } else {
      let mode = parse_octal(entry.mode)
      node.children[entry.name] = TreeNode::new_file(entry.id, mode)
    }
  }
}

///|
fn delete_from_tree(
  db_opt : @lib.ObjectDb?,
  rfs : &@bit.RepoFileSystem,
  root : TreeNode,
  path : String,
) -> Unit raise @bit.GitError {
  let parts = split_path(path)
  guard parts.length() > 0 else { return }
  let _ = delete_recursive(db_opt, rfs, root, parts, 0)
}

///|
fn delete_recursive(
  db_opt : @lib.ObjectDb?,
  rfs : &@bit.RepoFileSystem,
  node : TreeNode,
  parts : Array[String],
  idx : Int,
) -> Bool raise @bit.GitError {
  if idx >= parts.length() {
    return false
  }
  ensure_dir_loaded(db_opt, rfs, node)
  let name = parts[idx]
  if idx == parts.length() - 1 {
    if node.children.contains(name) {
      node.children.remove(name)
      node.dirty = true
      return true
    }
    return false
  }
  match node.children.get(name) {
    Some(child) => {
      if child.blob_id is Some(_) {
        return false
      }
      let deleted = delete_recursive(db_opt, rfs, child, parts, idx + 1)
      if deleted {
        if child.children.length() == 0 {
          node.children.remove(name)
        }
        node.dirty = true
      }
      deleted
    }
    None => false
  }
}

///|
fn insert_into_tree(
  db_opt : @lib.ObjectDb?,
  rfs : &@bit.RepoFileSystem,
  root : TreeNode,
  path : String,
  blob_id : @bit.ObjectId,
  mode : Int,
) -> Unit raise @bit.GitError {
  let parts = split_path(path)
  guard parts.length() > 0 else { return }
  ensure_dir_loaded(db_opt, rfs, root)
  root.dirty = true
  let mut current = root
  for i = 0; i < parts.length() - 1; i = i + 1 {
    ensure_dir_loaded(db_opt, rfs, current)
    let name = parts[i]
    if current.children.get(name) is Some(child) {
      if child.blob_id is Some(_) {
        let dir = TreeNode::new_dir()
        dir.dirty = true
        current.children[name] = dir
        current.dirty = true
        current = dir
      } else {
        ensure_dir_loaded(db_opt, rfs, child)
        child.dirty = true
        current = child
      }
    } else {
      let child = TreeNode::new_dir()
      child.dirty = true
      current.children[name] = child
      current.dirty = true
      current = child
    }
  }
  ensure_dir_loaded(db_opt, rfs, current)
  let file_name = parts[parts.length() - 1]
  current.children[file_name] = TreeNode::new_file(blob_id, mode)
  current.dirty = true
}

///|
fn write_tree_recursive(
  fs : &@bit.FileSystem,
  git_dir : String,
  node : TreeNode,
) -> @bit.ObjectId raise @bit.GitError {
  if not(node.dirty) {
    if node.base_tree_id is Some(base_tree_id) {
      return base_tree_id
    }
  }
  let entries : Array[@bit.TreeEntry] = []
  for item in node.children.to_array() {
    let (name, child) = item
    let (id, mode_str) = match child.blob_id {
      Some(blob_id) => (blob_id, mode_to_string(child.mode))
      None => {
        let subtree_id = write_tree_recursive(fs, git_dir, child)
        (subtree_id, "40000")
      }
    }
    entries.push(@bit.TreeEntry::new(mode_str, name, id))
  }
  entries.sort_by(fn(a, b) {
    let a_key = if a.mode == "40000" { a.name + "/" } else { a.name }
    let b_key = if b.mode == "40000" { b.name + "/" } else { b.name }
    compare_strings(a_key, b_key)
  })
  let (tree_id, compressed) = @bit.create_tree(entries)
  if node.base_tree_id != Some(tree_id) {
    @lib.write_object_bytes(fs, git_dir, tree_id, compressed)
  }
  tree_id
}

///|
fn parse_octal(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c < '0' || c > '7' {
      continue
    }
    result = result * 8 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
fn mode_to_string(mode : Int) -> String {
  if mode == 0o100644 {
    "100644"
  } else if mode == 0o100755 {
    "100755"
  } else if mode == 0o120000 {
    "120000"
  } else {
    to_octal_string(mode)
  }
}

///|
fn to_octal_string(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let digits : Array[Char] = []
  let mut v = value
  while v > 0 {
    let d = v % 8
    digits.push((d + '0'.to_int()).unsafe_to_char())
    v = v / 8
  }
  let rev = digits.rev()
  let sb = StringBuilder::new()
  for c in rev {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn compare_strings(a : String, b : String) -> Int {
  let a_len = a.length()
  let b_len = b.length()
  let min_len = if a_len < b_len { a_len } else { b_len }
  for i in 0..<min_len {
    let a_char = a.unsafe_get(i).to_int()
    let b_char = b.unsafe_get(i).to_int()
    if a_char < b_char {
      return -1
    } else if a_char > b_char {
      return 1
    }
  }
  if a_len < b_len {
    -1
  } else if a_len > b_len {
    1
  } else {
    0
  }
}
