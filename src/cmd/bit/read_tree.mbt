///| Plumbing handlers: read-tree, update-index, mktree, request-pull, send-pack, range-diff

///|
async fn handle_read_tree(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut reset = false
  let mut update = false
  let mut dry_run = false
  let mut empty = false
  let tree_refs : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-m" => () // Merge mode - simplified
      "--reset" => reset = true
      "-u" => update = true
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
      @bitlib.write_index_entries(fs, git_dir, [])
    }
    return
  }
  if tree_refs.length() == 0 {
    eprint_line("fatal: must specify tree-ish")
    @sys.exit(128)
    return
  }
  // Resolve tree-ish to tree object
  let tree_id = match @bitrepo.rev_parse(fs, git_dir, tree_refs[0]) {
    Some(id) => plumb_resolve_to_tree(fs, git_dir, id)
    None => {
      eprint_line("fatal: not a valid object name: " + tree_refs[0])
      @sys.exit(128)
      return
    }
  }
  // Collect tree files
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let files = @bitlib.collect_tree_files(db, fs, tree_id)
  // Get entries from tree
  let entries = @bitlib.tree_files_to_index(db, fs, files)
  // Write to index
  if not(dry_run) {
    @bitlib.write_index_entries(fs, git_dir, entries)
  }
  // Handle -u: update working tree
  if update && not(dry_run) {
    let root = get_work_root()
    @bitlib.write_worktree_from_files(
      db,
      fs,
      fs,
      root,
      git_dir,
      files,
      remove_missing=reset,
    )
  }
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
