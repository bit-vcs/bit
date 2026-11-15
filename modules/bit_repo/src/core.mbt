///| Pure repository object store and tree/commit parsing

///|
pub struct ObjectStore {
  objects : Map[String, @object.PackObject]
}

///|
pub fn ObjectStore::new() -> ObjectStore {
  { objects: Map([]) }
}

///|
pub fn ObjectStore::from_pack(
  objects : Array[@object.PackObject],
) -> ObjectStore {
  let store = ObjectStore::new()
  store.add_objects(objects)
  store
}

///|
pub fn ObjectStore::add_objects(
  self : ObjectStore,
  objects : Array[@object.PackObject],
) -> Unit {
  for obj in objects {
    // Use cached id if available (offset >= 0 means it was parsed from pack)
    let id = if obj.offset >= 0 {
      obj.id
    } else {
      @object.hash_object_content(obj.obj_type, obj.data)
    }
    self.objects[id.to_hex()] = obj
  }
}

///|
pub fn ObjectStore::get(
  self : ObjectStore,
  id : @object.ObjectId,
) -> @object.PackObject? {
  self.objects.get(id.to_hex())
}

///|
pub fn ObjectStore::contains(self : ObjectStore, id : @object.ObjectId) -> Bool {
  match self.objects.get(id.to_hex()) {
    Some(_) => true
    None => false
  }
}

///|
pub struct CommitInfo {
  tree : @object.ObjectId
  parents : Array[@object.ObjectId]
}

///|
pub fn parse_commit(content : Bytes) -> CommitInfo raise @object.GitError {
  let text = @utf8.decode_lossy(content[:])
  let mut tree_id : @object.ObjectId? = None
  let parents : Array[@object.ObjectId] = []
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    if line.length() == 0 {
      break
    }
    if line.has_prefix("tree ") {
      let hex = String::unsafe_substring(line, start=5, end=line.length())
      tree_id = hex |> @object.ObjectId::from_hex |> Some
    } else if line.has_prefix("parent ") {
      let hex = String::unsafe_substring(line, start=7, end=line.length())
      parents.push(@object.ObjectId::from_hex(hex))
    }
  }
  match tree_id {
    Some(tree) => { tree, parents }
    None => raise @object.GitError::InvalidObject("Missing tree in commit")
  }
}

///|
fn parse_tree_mode_is_octal(mode : String) -> Bool {
  if mode.length() == 0 {
    return false
  }
  for c in mode {
    if c < '0' || c > '7' {
      return false
    }
  }
  true
}

///|
fn parse_tree_with_hash_size(
  content : Bytes,
  hash_size : Int,
) -> Array[@object.TreeEntry] raise @object.GitError {
  let entries : Array[@object.TreeEntry] = []
  let mut i = 0
  while i < content.length() {
    // Parse mode (ASCII only, so byte-by-byte is fine)
    let mode_buf = StringBuilder()
    while i < content.length() && content[i] != b' ' {
      mode_buf.write_char(content[i].to_int().unsafe_to_char())
      i += 1
    }
    if i >= content.length() {
      raise @object.GitError::InvalidObject("Truncated tree entry mode")
    }
    let mode = mode_buf.to_string()
    if !parse_tree_mode_is_octal(mode) {
      raise @object.GitError::InvalidObject("Invalid tree entry mode")
    }
    i += 1 // skip space
    // Parse name - collect bytes and decode as UTF-8
    let name_start = i
    while i < content.length() && content[i] != b'\x00' {
      i += 1
    }
    if i >= content.length() {
      raise @object.GitError::InvalidObject("Truncated tree entry name")
    }
    let name_len = i - name_start
    let name_bytes = FixedArray::makei(name_len, fn(j) {
      content[name_start + j]
    })
    let name = @utf8.decode_lossy(Bytes::from_array(name_bytes)[:])
    i += 1 // skip NUL
    if i + hash_size > content.length() {
      raise @object.GitError::InvalidObject("Truncated tree entry id")
    }
    let id = @object.ObjectId::from_bytes_at(content, i, hash_size~)
    i += hash_size
    entries.push(@object.TreeEntry::new(mode, name, id))
  }
  entries
}

///|
pub fn parse_tree(
  content : Bytes,
) -> Array[@object.TreeEntry] raise @object.GitError {
  if content.length() == 0 {
    return []
  }
  parse_tree_with_hash_size(content, 20) catch {
    _ =>
      parse_tree_with_hash_size(content, 32) catch {
        _ => raise @object.GitError::InvalidObject("Invalid tree object")
      }
  }
}

///|
pub fn checkout_commit(
  store : ObjectStore,
  commit_id : @object.ObjectId,
) -> Map[String, Bytes] raise @object.GitError {
  let commit_obj = store.get(commit_id)
  match commit_obj {
    None => raise @object.GitError::InvalidObject("Missing commit object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Commit {
        raise @object.GitError::InvalidObject("Object is not a commit")
      }
      let info = parse_commit(obj.data)
      let files : Map[String, Bytes] = Map([])
      walk_tree(store, info.tree, "", files)
      files
    }
  }
}

///|
/// Materialize `commit_id` under `root`, producing an exact checkout: paths
/// tracked by a prior checkout that are absent from this commit are removed.
/// `rfs` must observe the same filesystem as `fs` (callers pass the same
/// concrete value as both trait views).
pub fn checkout_commit_to_fs(
  store : ObjectStore,
  commit_id : @object.ObjectId,
  fs : &@types.FileSystem,
  root : String,
  rfs : &@types.RepoFileSystem,
) -> Unit raise @object.GitError {
  let commit_obj = store.get(commit_id)
  match commit_obj {
    None => raise @object.GitError::InvalidObject("Missing commit object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Commit {
        raise @object.GitError::InvalidObject("Object is not a commit")
      }
      let info = parse_commit(obj.data)
      let files : Map[String, Bool] = Map([])
      let opaque_dirs : Map[String, Bool] = Map([])
      collect_tree_paths(store, info.tree, "", files, opaque_dirs)
      remove_stale_worktree_paths(rfs, fs, root, files, opaque_dirs)
      walk_tree_to_fs(store, info.tree, "", fs, root)
    }
  }
}

///|
/// Collect the set of blob paths (`files`) and gitlink/submodule mount
/// points (`opaque_dirs`) a tree will materialize to, without touching disk.
fn collect_tree_paths(
  store : ObjectStore,
  tree_id : @object.ObjectId,
  prefix : String,
  files : Map[String, Bool],
  opaque_dirs : Map[String, Bool],
) -> Unit raise @object.GitError {
  let tree_obj = store.get(tree_id)
  match tree_obj {
    None => raise @object.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Tree {
        raise @object.GitError::InvalidObject("Object is not a tree")
      }
      let entries = parse_tree(obj.data)
      for entry in entries {
        verify_tree_entry_name(entry.name, mode=entry.mode)
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          collect_tree_paths(store, entry.id, path, files, opaque_dirs)
        } else if is_gitlink_mode(entry.mode) {
          opaque_dirs[path] = true
        } else {
          files[path] = true
        }
      }
    }
  }
}

///|
/// Remove worktree paths under `root` that are not part of the target tree
/// (`keep_files`), skipping `.git` and any gitlink/submodule mount point
/// (`opaque_dirs`) so submodule checkouts are left untouched. Returns
/// whether the directory ended up with nothing left in it.
fn remove_stale_worktree_paths(
  rfs : &@types.RepoFileSystem,
  fs : &@types.FileSystem,
  root : String,
  keep_files : Map[String, Bool],
  opaque_dirs : Map[String, Bool],
) -> Unit raise @object.GitError {
  ignore(remove_stale_dir(rfs, fs, root, "", keep_files, opaque_dirs))
}

///|
fn remove_stale_dir(
  rfs : &@types.RepoFileSystem,
  fs : &@types.FileSystem,
  root : String,
  rel_dir : String,
  keep_files : Map[String, Bool],
  opaque_dirs : Map[String, Bool],
) -> Bool raise @object.GitError {
  let full_dir = if rel_dir.length() == 0 {
    root
  } else {
    join_path(root, rel_dir)
  }
  if !rfs.is_dir(full_dir) {
    return true
  }
  let names = rfs.readdir(full_dir)
  let mut emptied = true
  for name in names {
    if rel_dir.length() == 0 && name == ".git" {
      emptied = false
      continue
    }
    let rel_path = if rel_dir.length() == 0 {
      name
    } else {
      rel_dir + "/" + name
    }
    if opaque_dirs.contains(rel_path) {
      emptied = false
      continue
    }
    let full_path = join_path(root, rel_path)
    if rfs.is_dir(full_path) {
      let child_emptied = remove_stale_dir(
        rfs, fs, root, rel_path, keep_files, opaque_dirs,
      )
      if child_emptied {
        fs.remove_dir(full_path)
      } else {
        emptied = false
      }
    } else if keep_files.contains(rel_path) {
      emptied = false
    } else {
      fs.remove_file(full_path)
    }
  }
  emptied
}

///|
fn walk_tree(
  store : ObjectStore,
  tree_id : @object.ObjectId,
  prefix : String,
  files : Map[String, Bytes],
) -> Unit raise @object.GitError {
  let tree_obj = store.get(tree_id)
  match tree_obj {
    None => raise @object.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Tree {
        raise @object.GitError::InvalidObject("Object is not a tree")
      }
      let entries = parse_tree(obj.data)
      for entry in entries {
        verify_tree_entry_name(entry.name, mode=entry.mode)
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          walk_tree(store, entry.id, path, files)
        } else if is_gitlink_mode(entry.mode) {
          // Skip gitlinks (submodules) when materializing file contents.
        } else {
          let blob_obj = store.get(entry.id)
          match blob_obj {
            None => raise @object.GitError::InvalidObject("Missing blob object")
            Some(b) => {
              if b.obj_type != @object.ObjectType::Blob {
                raise @object.GitError::InvalidObject("Object is not a blob")
              }
              files[path] = b.data
            }
          }
        }
      }
    }
  }
}

///|
fn walk_tree_to_fs(
  store : ObjectStore,
  tree_id : @object.ObjectId,
  prefix : String,
  fs : &@types.FileSystem,
  root : String,
) -> Unit raise @object.GitError {
  let tree_obj = store.get(tree_id)
  match tree_obj {
    None => raise @object.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @object.ObjectType::Tree {
        raise @object.GitError::InvalidObject("Object is not a tree")
      }
      let entries = parse_tree(obj.data)
      for entry in entries {
        verify_tree_entry_name(entry.name, mode=entry.mode)
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          walk_tree_to_fs(store, entry.id, path, fs, root)
        } else if is_gitlink_mode(entry.mode) {
          let full_path = join_path(root, path)
          fs.mkdir_p(full_path)
        } else {
          let blob_obj = store.get(entry.id)
          match blob_obj {
            None => raise @object.GitError::InvalidObject("Missing blob object")
            Some(b) => {
              if b.obj_type != @object.ObjectType::Blob {
                raise @object.GitError::InvalidObject("Object is not a blob")
              }
              let full_path = join_path(root, path)
              let dir = parent_dir(full_path)
              fs.mkdir_p(dir)
              fs.write_file(full_path, b.data)
            }
          }
        }
      }
    }
  }
}

///|
pub fn is_tree_mode(mode : String) -> Bool {
  mode == "40000" || mode == "040000"
}

///|
pub fn is_gitlink_mode(mode : String) -> Bool {
  mode == "160000" || mode == "0160000"
}

///|
pub fn join_path(root : String, path : String) -> String {
  if root.length() == 0 || root == "/" {
    if path.has_prefix("/") {
      path
    } else {
      "/" + path
    }
  } else if root.has_suffix("/") {
    root + path
  } else {
    root + "/" + path
  }
}

///|
pub fn parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => "/"
    Some(0) => "/"
    Some(i) => String::unsafe_substring(path, start=0, end=i)
  }
}

///|
/// Verify a single tree-entry name is safe to materialize into a
/// worktree path.
///
/// Rejects: empty string, `.`, `..`, any name containing `/` or NUL,
/// and any spelling of a repository marker (`.git`, and bit's own `.bit`)
/// that a filesystem may resolve to the marker itself:
///
/// - ASCII case-insensitively (`.GIT`, `.Bit`);
/// - NTFS forms, as git's `is_ntfs_dotgit`: trailing dots/spaces
///   (`.git.`, `.git `), the 8.3 short name `git~1`, an alternate data
///   stream (`.git::$INDEX_ALLOCATION`), and each `\\`-separated segment;
/// - HFS+ forms, as git's `is_hfs_dotgit`: the marker with Unicode
///   ignorable code points interleaved (`.g\u{200c}it`).
///
/// The NTFS and HFS+ sets follow `core.protectNTFS` / `core.protectHFS`
/// (see `set_tree_path_protection`); both are on by default.
///
/// `mode`, when given, is the entry's tree mode. A symlink (`120000`)
/// named `.gitmodules`, `.gitattributes`, `.gitignore` or `.mailmap`
/// (in any of the spellings above) is rejected, as git does: bit and git
/// read those files from the worktree and must not follow a link out
/// of it.
///
/// Called at the bytes→worktree boundary (`walk_tree_to_fs`,
/// `lib.collect_tree_files_inner`). Reading the bytes via
/// `@object.parse_tree` is unaffected: a repo might still contain
/// legacy commits with names we now reject, but bit refuses to
/// materialize them. Use `git fsck --strict` upstream to catch the
/// commit; bit will not silently write into `.git/` or above the
/// worktree.
pub fn verify_tree_entry_name(
  name : String,
  mode? : String = "",
) -> Unit raise @object.GitError {
  if name.length() == 0 {
    raise @object.GitError::InvalidObject("tree entry: empty name")
  }
  if name == "." || name == ".." {
    raise @object.GitError::InvalidObject("tree entry: name is '\{name}'")
  }
  for i in 0..<name.length() {
    let c = name.unsafe_get(i)
    if c == '/' || c == 0 {
      raise @object.GitError::InvalidObject(
        "tree entry: name contains separator or NUL: '\{name}'",
      )
    }
  }
  let (protect_hfs, protect_ntfs) = tree_path_protection.val
  let aliases = fn(base : String) {
    tree_name_ascii_fold(name) == "." + base ||
    (protect_ntfs && tree_name_is_ntfs_dot(name, base)) ||
    (protect_hfs && tree_name_is_hfs_dot(name, base))
  }
  for marker in ["git", "bit"] {
    if aliases(marker) {
      raise @object.GitError::InvalidObject(
        "tree entry: name aliases '.\{marker}': '\{name}'",
      )
    }
  }
  if mode == "120000" {
    for dotfile in ["gitmodules", "gitattributes", "gitignore", "mailmap"] {
      if aliases(dotfile) {
        raise @object.GitError::InvalidObject(
          "tree entry: '.\{dotfile}' is a symbolic link",
        )
      }
    }
  }
}

///|
/// (core.protectHFS, core.protectNTFS) as applied by
/// `verify_tree_entry_name`. Both default to on: git enables protectNTFS
/// everywhere, and bit also enables the HFS+ checks off macOS because a
/// clone may later be used from one. The CLI lowers them from repository
/// config via `set_tree_path_protection`.
let tree_path_protection : Ref[(Bool, Bool)] = { val: (true, true) }

///|
/// Set which filesystem-specific `.git` aliases `verify_tree_entry_name`
/// rejects (git's `core.protectHFS` / `core.protectNTFS`). Plain `.git`
/// and `.bit`, in any ASCII case, are always rejected.
pub fn set_tree_path_protection(hfs~ : Bool, ntfs~ : Bool) -> Unit {
  tree_path_protection.val = (hfs, ntfs)
}

///|
fn tree_name_ascii_fold(name : String) -> String {
  let out = StringBuilder::new()
  for c in name {
    out.write_char(Int::unsafe_to_char(tree_name_ascii_lower(c.to_int())))
  }
  out.to_string()
}

///|
fn tree_name_ascii_lower(c : Int) -> Int {
  if c >= 0x41 && c <= 0x5A {
    c + 32
  } else {
    c
  }
}

///|
/// `seg[start:]` begins with `word` (ASCII, compared case-insensitively).
fn tree_name_has_word_at(seg : String, start : Int, word : String) -> Bool {
  if start + word.length() > seg.length() {
    return false
  }
  for i in 0..<word.length() {
    if tree_name_ascii_lower(seg.unsafe_get(start + i).to_int()) !=
      word.unsafe_get(i).to_int() {
      return false
    }
  }
  true
}

///|
/// NTFS resolves `seg` to `.<marker>`: `.<marker>` or the 8.3 short name
/// `<first 6 of marker>~1`, followed only by dots/spaces, or by `:` (an
/// alternate data stream such as `::$INDEX_ALLOCATION`). Each
/// backslash-separated segment is checked, since `\\` is a separator
/// on Windows.
fn tree_name_is_ntfs_dot(name : String, marker : String) -> Bool {
  let stem = if marker.length() > 6 {
    String::unsafe_substring(marker, start=0, end=6)
  } else {
    marker
  }
  let short = stem + "~1"
  for seg_view in name.split("\\") {
    let seg = seg_view.to_owned()
    let rest = if seg.length() > 0 &&
      seg.unsafe_get(0) == '.' &&
      tree_name_has_word_at(seg, 1, marker) {
      1 + marker.length()
    } else if tree_name_has_word_at(seg, 0, short) {
      short.length()
    } else {
      continue
    }
    let mut only_trailing = true
    for i in rest..<seg.length() {
      let c = seg.unsafe_get(i)
      if c == ':' {
        break
      }
      if c != '.' && c != ' ' {
        only_trailing = false
        break
      }
    }
    if only_trailing {
      return true
    }
  }
  false
}

///|
/// Code points HFS+ ignores when comparing names (git's `next_hfs_char`).
fn tree_name_is_hfs_ignorable(c : Int) -> Bool {
  (c >= 0x200C && c <= 0x200F) || // ZWNJ, ZWJ, LRM, RLM
  (c >= 0x202A && c <= 0x202E) || // bidi embeddings / overrides
  (c >= 0x206A && c <= 0x206F) || // deprecated format characters
  c == 0xFEFF // zero-width no-break space
}

///|
/// HFS+ resolves `name` to `.<marker>` once ignorable code points are
/// dropped and ASCII is folded to lower case.
fn tree_name_is_hfs_dot(name : String, marker : String) -> Bool {
  let folded = StringBuilder::new()
  for c in name {
    let cp = c.to_int()
    if tree_name_is_hfs_ignorable(cp) {
      continue
    }
    folded.write_char(Int::unsafe_to_char(tree_name_ascii_lower(cp)))
  }
  folded.to_string() == "." + marker
}
