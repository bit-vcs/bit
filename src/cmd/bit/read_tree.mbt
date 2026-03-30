///| Plumbing handlers: read-tree, update-index, mktree, request-pull, send-pack, range-diff

///|
async fn handle_read_tree(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let hash_size = @bitlib.repo_hash_algorithm(fs, git_dir).hash_size()
  let mut merge = false
  let mut reset = false
  let mut update = false
  let mut dry_run = false
  let mut empty = false
  let mut index_only = false
  let tree_refs : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-m" => merge = true
      "--reset" => reset = true
      "-u" => update = true
      "-i" => index_only = true
      "-n" | "--dry-run" => dry_run = true
      "--empty" => empty = true
      "--prefix" if i + 1 < args.length() => {
        i += 2
        continue
      }
      "--index-output" if i + 1 < args.length() => {
        i += 2
        continue
      }
      _ if arg.has_prefix("--prefix=") => ()
      _ if arg.has_prefix("--index-output=") => ()
      _ if not(arg.has_prefix("-")) => tree_refs.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("read-tree", arg)
      _ => ()
    }
    i += 1
  }
  // Handle --empty: clear index
  if empty {
    if not(dry_run) {
      @bitlib.write_index_entries(fs, git_dir, [], hash_size~)
    }
    return
  }
  if tree_refs.length() == 0 {
    eprint_line("fatal: must specify tree-ish")
    @sys.exit(128)
    return
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  if tree_refs.length() == 1 {
    // Single tree read
    let tree_id = match @bitrepo.rev_parse(fs, git_dir, tree_refs[0]) {
      Some(id) => plumb_resolve_to_tree(fs, git_dir, id)
      None => {
        eprint_line("fatal: not a valid object name: " + tree_refs[0])
        @sys.exit(128)
        return
      }
    }
    let files = @bitlib.collect_tree_files(db, fs, tree_id)
    let entries = @bitlib.tree_files_to_index(db, fs, files)
    if not(dry_run) {
      @bitlib.write_index_entries(fs, git_dir, entries, hash_size~)
    }
    // Handle -u: update working tree (unless -i: index only)
    if update && not(dry_run) && not(index_only) {
      let root = get_work_root()
      @bitlib.write_worktree_from_files(
        db,
        fs,
        fs,
        root,
        git_dir,
        files,
        remove_missing=reset || merge,
      )
    }
  } else {
    // Multi-tree overlay read: union of all trees' files
    // Later trees take precedence for conflicting paths
    let merged_files : Map[String, @bitlib.TreeFileEntry] = {}
    for tree_ref in tree_refs {
      let tree_id = match @bitrepo.rev_parse(fs, git_dir, tree_ref) {
        Some(id) => plumb_resolve_to_tree(fs, git_dir, id)
        None => {
          eprint_line("fatal: not a valid object name: " + tree_ref)
          @sys.exit(128)
          return
        }
      }
      let files = @bitlib.collect_tree_files(db, fs, tree_id)
      for path, entry in files {
        merged_files[path] = entry
      }
    }
    let entries = @bitlib.tree_files_to_index(db, fs, merged_files)
    if not(dry_run) {
      @bitlib.write_index_entries(fs, git_dir, entries, hash_size~)
    }
    if update && not(dry_run) && not(index_only) {
      let root = get_work_root()
      @bitlib.write_worktree_from_files(
        db,
        fs,
        fs,
        root,
        git_dir,
        merged_files,
        remove_missing=reset,
      )
    }
  }
  // Suppress unused variable warnings
  ignore(merge)
}

///|
fn plumb_resolve_to_tree(
  fs : OsFs,
  git_dir : String,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId raise Error {
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  match db.get(fs, id) {
    Some(obj) =>
      match obj.obj_type {
        @bitcore.ObjectType::Tree => id
        @bitcore.ObjectType::Commit => {
          let info = @bitcore.parse_commit(obj.data)
          info.tree
        }
        @bitcore.ObjectType::Tag => {
          // Parse tag and follow to target
          let text = decode_bytes(obj.data)
          for line_view in text.split("\n") {
            let line = line_view.to_string()
            if line.has_prefix("object ") {
              let target_hex = line[7:].to_string()
              let target = @bitcore.ObjectId::from_hex(target_hex)
              return plumb_resolve_to_tree(fs, git_dir, target)
            }
          }
          raise @bitcore.GitError::InvalidObject("Invalid tag object")
        }
        _ => raise @bitcore.GitError::InvalidObject("Cannot resolve to tree")
      }
    None => raise @bitcore.GitError::InvalidObject("Object not found")
  }
}

///|
