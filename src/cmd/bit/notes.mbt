///|
async fn handle_notes(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let mut ref_name : String? = None
  let rest : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--ref" if i + 1 < args.length() => {
        ref_name = Some(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("--ref=") => {
        ref_name = Some((try! arg[6:]).to_string())
        i += 1
        continue
      }
      _ => {
        rest.push(arg)
        i += 1
        continue
      }
    }
  }
  let notes_ref = normalize_notes_ref(ref_name)
  let notes_ref_path = git_dir + "/" + notes_ref
  // Parse subcommand
  let subcmd = rest.get(0).unwrap_or("list")
  let subargs : Array[String] = []
  for i in 1..<rest.length() {
    subargs.push(rest[i])
  }
  match subcmd {
    "list" => notes_list(rfs, git_dir, notes_ref_path)
    "show" => {
      let commit_ref = subargs.get(0).unwrap_or("HEAD")
      notes_show(rfs, git_dir, notes_ref_path, commit_ref)
    }
    "add" => {
      let mut message : String? = None
      let mut force = false
      let mut commit_ref = "HEAD"
      let mut i = 0
      while i < subargs.length() {
        let arg = subargs[i]
        match arg {
          "-m" | "--message" if i + 1 < subargs.length() => {
            message = Some(subargs[i + 1])
            i += 2
            continue
          }
          _ if arg.has_prefix("-m") => {
            message = Some((try! arg[2:]).to_string())
            i += 1
            continue
          }
          _ if arg.has_prefix("--message=") => {
            message = Some((try! arg[10:]).to_string())
            i += 1
            continue
          }
          "-f" | "--force" => {
            force = true
            i += 1
            continue
          }
          _ if not(arg.has_prefix("-")) => {
            commit_ref = arg
            i += 1
            continue
          }
          _ => i += 1
        }
      }
      guard message is Some(msg) else {
        @stdio.stderr.write("error: notes add requires -m <message>")
        @sys.exit(1)
      }
      notes_add(wfs, rfs, git_dir, notes_ref_path, commit_ref, msg, force)
    }
    "append" => {
      let mut message : String? = None
      let mut commit_ref = "HEAD"
      let mut i = 0
      while i < subargs.length() {
        let arg = subargs[i]
        match arg {
          "-m" | "--message" if i + 1 < subargs.length() => {
            message = Some(subargs[i + 1])
            i += 2
            continue
          }
          _ if arg.has_prefix("-m") => {
            message = Some((try! arg[2:]).to_string())
            i += 1
            continue
          }
          _ if arg.has_prefix("--message=") => {
            message = Some((try! arg[10:]).to_string())
            i += 1
            continue
          }
          _ if not(arg.has_prefix("-")) => {
            commit_ref = arg
            i += 1
            continue
          }
          _ => i += 1
        }
      }
      guard message is Some(msg) else {
        @stdio.stderr.write("error: notes append requires -m <message>")
        @sys.exit(1)
      }
      notes_append(wfs, rfs, git_dir, notes_ref_path, commit_ref, msg)
    }
    "edit" => {
      let mut message : String? = None
      let mut commit_ref = "HEAD"
      let mut i = 0
      while i < subargs.length() {
        let arg = subargs[i]
        match arg {
          "-m" | "--message" if i + 1 < subargs.length() => {
            message = Some(subargs[i + 1])
            i += 2
            continue
          }
          _ if arg.has_prefix("-m") => {
            message = Some((try! arg[2:]).to_string())
            i += 1
            continue
          }
          _ if arg.has_prefix("--message=") => {
            message = Some((try! arg[10:]).to_string())
            i += 1
            continue
          }
          _ if not(arg.has_prefix("-")) => {
            commit_ref = arg
            i += 1
            continue
          }
          _ => i += 1
        }
      }
      guard message is Some(msg) else {
        @stdio.stderr.write("error: notes edit requires -m <message>")
        @sys.exit(1)
      }
      notes_add(wfs, rfs, git_dir, notes_ref_path, commit_ref, msg, true)
    }
    "copy" => {
      let mut force = false
      let mut from_ref : String? = None
      let mut to_ref : String? = None
      let mut i = 0
      while i < subargs.length() {
        let arg = subargs[i]
        match arg {
          "-f" | "--force" => {
            force = true
            i += 1
            continue
          }
          _ if not(arg.has_prefix("-")) => {
            if from_ref is None {
              from_ref = Some(arg)
            } else if to_ref is None {
              to_ref = Some(arg)
            }
            i += 1
            continue
          }
          _ => i += 1
        }
      }
      guard from_ref is Some(from_commit) else {
        @stdio.stderr.write("usage: git notes copy <from> <to>")
        @sys.exit(1)
      }
      guard to_ref is Some(to_commit) else {
        @stdio.stderr.write("usage: git notes copy <from> <to>")
        @sys.exit(1)
      }
      notes_copy(
        wfs, rfs, git_dir, notes_ref_path, from_commit, to_commit, force,
      )
    }
    "merge" => {
      let mut strategy : String? = None
      let mut other_ref : String? = None
      let mut i = 0
      while i < subargs.length() {
        let arg = subargs[i]
        match arg {
          "-s" if i + 1 < subargs.length() => {
            strategy = Some(subargs[i + 1])
            i += 2
            continue
          }
          "--strategy" if i + 1 < subargs.length() => {
            strategy = Some(subargs[i + 1])
            i += 2
            continue
          }
          _ if arg.has_prefix("--strategy=") => {
            strategy = Some((try! arg[11:]).to_string())
            i += 1
            continue
          }
          _ if not(arg.has_prefix("-")) => {
            other_ref = Some(arg)
            i += 1
            continue
          }
          _ => i += 1
        }
      }
      guard other_ref is Some(other_name) else {
        @stdio.stderr.write("usage: git notes merge <ref>")
        @sys.exit(1)
      }
      match strategy {
        Some(s) =>
          if s != "ours" &&
            s != "theirs" &&
            s != "union" &&
            s != "cat_sort_uniq" {
            @stdio.stderr.write("error: unsupported merge strategy: \{s}")
            @sys.exit(1)
          }
        None => ()
      }
      let other_ref_path = git_dir +
        "/" +
        (other_name |> Some |> normalize_notes_ref)
      notes_merge(wfs, rfs, git_dir, notes_ref_path, other_ref_path, strategy)
    }
    "rewrite" => {
      let mut force = false
      let mut use_stdin = false
      let mut from_ref : String? = None
      let mut to_ref : String? = None
      let mut i = 0
      while i < subargs.length() {
        let arg = subargs[i]
        match arg {
          "--stdin" => {
            use_stdin = true
            i += 1
            continue
          }
          "-f" | "--force" => {
            force = true
            i += 1
            continue
          }
          _ if not(arg.has_prefix("-")) => {
            if from_ref is None {
              from_ref = Some(arg)
            } else if to_ref is None {
              to_ref = Some(arg)
            }
            i += 1
            continue
          }
          _ => i += 1
        }
      }
      if use_stdin {
        if from_ref is Some(_) || to_ref is Some(_) {
          @stdio.stderr.write(
            "usage: git notes rewrite [--stdin] [-f] [<from> <to>]",
          )
          @sys.exit(1)
        }
        let data = read_all_stdin()
        let text = decode_bytes(data)
        let lines = split_lines(text)
        for line in lines {
          let parts = split_whitespace_tokens(line)
          if parts.length() != 2 {
            @stdio.stderr.write("error: invalid rewrite line: \{line}")
            @sys.exit(1)
          }
          let from = parts[0]
          let to = parts[1]
          notes_rewrite(wfs, rfs, git_dir, notes_ref_path, from, to, force)
        }
        return
      }
      guard from_ref is Some(from_commit) else {
        @stdio.stderr.write("usage: git notes rewrite <from> <to>")
        @sys.exit(1)
      }
      guard to_ref is Some(to_commit) else {
        @stdio.stderr.write("usage: git notes rewrite <from> <to>")
        @sys.exit(1)
      }
      notes_rewrite(
        wfs, rfs, git_dir, notes_ref_path, from_commit, to_commit, force,
      )
    }
    "remove" => {
      let commit_ref = subargs.get(0).unwrap_or("HEAD")
      notes_remove(wfs, rfs, git_dir, notes_ref_path, commit_ref)
    }
    "prune" => notes_prune(wfs, rfs, git_dir, notes_ref_path)
    _ => {
      @stdio.stderr.write(
        "usage: git notes [--ref <name>] [list | show | add | append | edit | copy | merge | rewrite | remove | prune]",
      )
      @sys.exit(1)
    }
  }
}

///|
async fn notes_list(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
) -> Unit raise Error {
  if not(rfs.is_file(notes_ref_path)) {
    return
  }
  let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
  let commit_hex = trim_string(ref_content)
  let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else { return }
  let commit_info = @bitcore.parse_commit(o.data)
  // Read tree
  let tree_obj = db.get(rfs, commit_info.tree)
  guard tree_obj is Some(to) else { return }
  let entries = @bitcore.parse_tree(to.data)
  for entry in entries {
    print_line("\{entry.id.to_hex()} \{entry.name}")
  }
}

///|
async fn notes_show(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  commit_ref : String,
) -> Unit raise Error {
  // Resolve target commit
  let target_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard target_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  let target_hex = tid.to_hex()
  // Check if notes ref exists
  if not(rfs.is_file(notes_ref_path)) {
    @stdio.stderr.write("error: no note found for \{target_hex}")
    @sys.exit(1)
  }
  let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
  let commit_hex = trim_string(ref_content)
  let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else {
    @stdio.stderr.write("error: notes ref corrupt")
    @sys.exit(1)
  }
  let commit_info = @bitcore.parse_commit(o.data)
  // Read tree
  let tree_obj = db.get(rfs, commit_info.tree)
  guard tree_obj is Some(to) else {
    @stdio.stderr.write("error: notes tree corrupt")
    @sys.exit(1)
  }
  let entries = @bitcore.parse_tree(to.data)
  // Find entry matching target commit
  for entry in entries {
    if entry.name == target_hex {
      let note_obj = db.get(rfs, entry.id)
      guard note_obj is Some(no) else {
        @stdio.stderr.write("error: note blob corrupt")
        @sys.exit(1)
      }
      no.data |> decode_bytes |> print_line
      return
    }
  }
  @stdio.stderr.write("error: no note found for \{target_hex}")
  @sys.exit(1)
}

///|
async fn notes_add(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  commit_ref : String,
  message : String,
  force : Bool,
) -> Unit raise Error {
  // Resolve target commit
  let target_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard target_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  let target_hex = tid.to_hex()
  // Create blob for note content
  let note_content = Bytes::from_array(
    message.to_array().map(c => c.to_int().to_byte()),
  )
  let note_id = @bitlib.write_loose_object(
    wfs,
    git_dir,
    @bitcore.ObjectType::Blob,
    note_content,
  )
  // Get existing tree entries if notes ref exists
  let entries : Array[@bitcore.TreeEntry] = []
  let mut parent_commit : @bitcore.ObjectId? = None
  if rfs.is_file(notes_ref_path) {
    let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
    let commit_hex = trim_string(ref_content)
    let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
    parent_commit = Some(commit_id)
    let db = @bitlib.ObjectDb::load(rfs, git_dir)
    let obj = db.get(rfs, commit_id)
    match obj {
      Some(o) => {
        let commit_info = @bitcore.parse_commit(o.data)
        let tree_obj = db.get(rfs, commit_info.tree)
        match tree_obj {
          Some(to) => {
            let existing = @bitcore.parse_tree(to.data)
            for e in existing {
              if e.name == target_hex {
                if not(force) {
                  @stdio.stderr.write(
                    "error: note already exists for \{target_hex}",
                  )
                  @stdio.stderr.write("Use -f to overwrite existing note")
                  @sys.exit(1)
                }
                // Skip existing note (will be replaced)
              } else {
                entries.push(e)
              }
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
  // Add new note entry
  entries.push(@bitcore.TreeEntry::new("100644", target_hex, note_id))
  // Sort entries by name (git requires sorted trees)
  entries.sort_by((a, b) => a.name.compare(b.name))
  // Create tree
  let (tree_id, tree_data) = @bitcore.create_tree(entries)
  @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
  // Create commit
  let author = get_author_string()
  let timestamp = @sys.get_env_var("GIT_COMMITTER_DATE")
    .map(parse_commit_date)
    .unwrap_or(get_current_timestamp())
  let parents = match parent_commit {
    Some(p) => [p]
    None => []
  }
  let commit = @bitcore.Commit::new(
    tree_id, parents, author, timestamp, "+0000", author, timestamp, "+0000", "Notes added by 'git notes add'\n",
  )
  let (commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, commit_id, commit_data)
  // Ensure refs/notes directory exists
  wfs.mkdir_p(git_dir + "/refs/notes")
  // Update notes ref
  wfs.write_string(notes_ref_path, commit_id.to_hex() + "\n")
}

///|
async fn notes_append(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  commit_ref : String,
  message : String,
) -> Unit raise Error {
  // Resolve target commit
  let target_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard target_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  let target_hex = tid.to_hex()
  // Get existing tree entries and note content if present
  let entries : Array[@bitcore.TreeEntry] = []
  let mut parent_commit : @bitcore.ObjectId? = None
  let mut existing_text : String? = None
  if rfs.is_file(notes_ref_path) {
    let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
    let commit_hex = trim_string(ref_content)
    let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
    parent_commit = Some(commit_id)
    let db = @bitlib.ObjectDb::load(rfs, git_dir)
    let obj = db.get(rfs, commit_id)
    guard obj is Some(o) else {
      @stdio.stderr.write("error: notes ref corrupt")
      @sys.exit(1)
    }
    let commit_info = @bitcore.parse_commit(o.data)
    let tree_obj = db.get(rfs, commit_info.tree)
    guard tree_obj is Some(to) else {
      @stdio.stderr.write("error: notes tree corrupt")
      @sys.exit(1)
    }
    let existing = @bitcore.parse_tree(to.data)
    for e in existing {
      if e.name == target_hex {
        let note_obj = db.get(rfs, e.id)
        guard note_obj is Some(no) else {
          @stdio.stderr.write("error: note blob corrupt")
          @sys.exit(1)
        }
        existing_text = no.data |> decode_bytes |> Some
      } else {
        entries.push(e)
      }
    }
  }
  let new_text = match existing_text {
    Some(text) => {
      let sep = if text == "" || text.has_suffix("\n") { "" } else { "\n" }
      text + sep + message
    }
    None => message
  }
  // Create blob for note content
  let note_content = Bytes::from_array(
    new_text.to_array().map(c => c.to_int().to_byte()),
  )
  let note_id = @bitlib.write_loose_object(
    wfs,
    git_dir,
    @bitcore.ObjectType::Blob,
    note_content,
  )
  // Add new note entry
  entries.push(@bitcore.TreeEntry::new("100644", target_hex, note_id))
  // Sort entries by name (git requires sorted trees)
  entries.sort_by((a, b) => a.name.compare(b.name))
  // Create tree
  let (tree_id, tree_data) = @bitcore.create_tree(entries)
  @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
  // Create commit
  let author = get_author_string()
  let timestamp = get_current_timestamp()
  let parents = match parent_commit {
    Some(p) => [p]
    None => []
  }
  let commit = @bitcore.Commit::new(
    tree_id, parents, author, timestamp, "+0000", author, timestamp, "+0000", "Notes appended by 'git notes append'\n",
  )
  let (commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, commit_id, commit_data)
  // Ensure refs/notes directory exists
  wfs.mkdir_p(git_dir + "/refs/notes")
  // Update notes ref
  wfs.write_string(notes_ref_path, commit_id.to_hex() + "\n")
}

///|
async fn notes_copy(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  from_ref : String,
  to_ref : String,
  force : Bool,
) -> Unit raise Error {
  // Resolve commits
  let from_id = @bitrepo.rev_parse(rfs, git_dir, from_ref)
  guard from_id is Some(fid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{from_ref}")
  }
  let to_id = @bitrepo.rev_parse(rfs, git_dir, to_ref)
  guard to_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{to_ref}")
  }
  let from_hex = fid.to_hex()
  let to_hex = tid.to_hex()
  if from_hex == to_hex {
    @stdio.stderr.write("error: note already exists for \{to_hex}")
    @sys.exit(1)
  }
  // Load notes tree
  if not(rfs.is_file(notes_ref_path)) {
    @stdio.stderr.write("error: no note found for \{from_hex}")
    @sys.exit(1)
  }
  let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
  let commit_hex = trim_string(ref_content)
  let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else {
    @stdio.stderr.write("error: notes ref corrupt")
    @sys.exit(1)
  }
  let commit_info = @bitcore.parse_commit(o.data)
  let tree_obj = db.get(rfs, commit_info.tree)
  guard tree_obj is Some(to) else {
    @stdio.stderr.write("error: notes tree corrupt")
    @sys.exit(1)
  }
  let existing = @bitcore.parse_tree(to.data)
  let entries : Array[@bitcore.TreeEntry] = []
  let mut source_entry : @bitcore.TreeEntry? = None
  let mut dest_exists = false
  for e in existing {
    if e.name == from_hex {
      source_entry = Some(e)
      entries.push(e)
    } else if e.name == to_hex {
      dest_exists = true
      if force {
        // skip existing destination
      } else {
        entries.push(e)
      }
    } else {
      entries.push(e)
    }
  }
  guard source_entry is Some(src) else {
    @stdio.stderr.write("error: no note found for \{from_hex}")
    @sys.exit(1)
  }
  if dest_exists && not(force) {
    @stdio.stderr.write("error: note already exists for \{to_hex}")
    @sys.exit(1)
  }
  entries.push(@bitcore.TreeEntry::new("100644", to_hex, src.id))
  entries.sort_by((a, b) => a.name.compare(b.name))
  let (tree_id, tree_data) = @bitcore.create_tree(entries)
  @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
  let author = get_author_string()
  let timestamp = get_current_timestamp()
  let commit = @bitcore.Commit::new(
    tree_id,
    [commit_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    "Notes copied by 'git notes copy'\n",
  )
  let (new_commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, new_commit_id, commit_data)
  wfs.mkdir_p(git_dir + "/refs/notes")
  wfs.write_string(notes_ref_path, new_commit_id.to_hex() + "\n")
}

///|
async fn notes_remove(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  commit_ref : String,
) -> Unit raise Error {
  // Resolve target commit
  let target_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard target_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  let target_hex = tid.to_hex()
  // Check if notes ref exists
  if not(rfs.is_file(notes_ref_path)) {
    @stdio.stderr.write("error: no note found for \{target_hex}")
    @sys.exit(1)
  }
  let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
  let commit_hex = trim_string(ref_content)
  let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else {
    @stdio.stderr.write("error: notes ref corrupt")
    @sys.exit(1)
  }
  let commit_info = @bitcore.parse_commit(o.data)
  let tree_obj = db.get(rfs, commit_info.tree)
  guard tree_obj is Some(to) else {
    @stdio.stderr.write("error: notes tree corrupt")
    @sys.exit(1)
  }
  let existing = @bitcore.parse_tree(to.data)
  // Filter out target entry
  let mut found = false
  let entries : Array[@bitcore.TreeEntry] = []
  for e in existing {
    if e.name == target_hex {
      found = true
    } else {
      entries.push(e)
    }
  }
  if not(found) {
    @stdio.stderr.write("error: no note found for \{target_hex}")
    @sys.exit(1)
  }
  // Create new tree
  let (tree_id, tree_data) = @bitcore.create_tree(entries)
  @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
  // Create commit
  let author = get_author_string()
  let timestamp = get_current_timestamp()
  let commit = @bitcore.Commit::new(
    tree_id,
    [commit_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    "Notes removed by 'git notes remove'\n",
  )
  let (new_commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, new_commit_id, commit_data)
  // Update notes ref
  wfs.write_string(notes_ref_path, new_commit_id.to_hex() + "\n")
  print_line("Removing note for \{target_hex}")
}

///|
async fn notes_prune(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
) -> Unit raise Error {
  // Check if notes ref exists
  if not(rfs.is_file(notes_ref_path)) {
    return
  }
  let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
  let commit_hex = trim_string(ref_content)
  let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else { return }
  let commit_info = @bitcore.parse_commit(o.data)
  let tree_obj = db.get(rfs, commit_info.tree)
  guard tree_obj is Some(to) else { return }
  let existing = @bitcore.parse_tree(to.data)
  // Filter entries where the referenced commit still exists
  let entries : Array[@bitcore.TreeEntry] = []
  let mut pruned = 0
  for e in existing {
    let ref_id = @bitcore.ObjectId::from_hex(e.name)
    let ref_obj = db.get(rfs, ref_id) catch {
      err if @async.is_cancellation_error(err) => raise err
      _ => None
    }
    match ref_obj {
      Some(_) => entries.push(e)
      None => pruned += 1
    }
  }
  if pruned == 0 {
    return
  }
  // Create new tree
  let (tree_id, tree_data) = @bitcore.create_tree(entries)
  @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
  // Create commit
  let author = get_author_string()
  let timestamp = get_current_timestamp()
  let commit = @bitcore.Commit::new(
    tree_id,
    [commit_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    "Notes pruned by 'git notes prune'\n",
  )
  let (new_commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, new_commit_id, commit_data)
  // Update notes ref
  wfs.write_string(notes_ref_path, new_commit_id.to_hex() + "\n")
  print_line("Pruned \{pruned} notes")
}

///|
async fn load_notes_tree(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
) -> (@bitcore.ObjectId, Array[@bitcore.TreeEntry])? raise Error {
  if not(rfs.is_file(notes_ref_path)) {
    return None
  }
  let ref_content = decode_bytes(rfs.read_file(notes_ref_path))
  let commit_hex = trim_string(ref_content)
  let commit_id = @bitcore.ObjectId::from_hex(commit_hex)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else {
    @stdio.stderr.write("error: notes ref corrupt")
    @sys.exit(1)
    return None
  }
  let commit_info = @bitcore.parse_commit(o.data)
  let tree_obj = db.get(rfs, commit_info.tree)
  guard tree_obj is Some(to) else {
    @stdio.stderr.write("error: notes tree corrupt")
    @sys.exit(1)
    return None
  }
  let entries = @bitcore.parse_tree(to.data)
  Some((commit_id, entries))
}

///|
async fn note_text(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  entry : @bitcore.TreeEntry,
) -> String raise Error {
  let obj = db.get(rfs, entry.id)
  guard obj is Some(o) else {
    @stdio.stderr.write("error: note blob corrupt")
    @sys.exit(1)
    return ""
  }
  decode_bytes(o.data)
}

///|
fn merge_notes_union(ours : String, theirs : String) -> String {
  if ours == "" {
    return theirs
  }
  if theirs == "" {
    return ours
  }
  let sep = if ours.has_suffix("\n") { "" } else { "\n" }
  ours + sep + theirs
}

///|
fn join_lines(lines : Array[String]) -> String {
  let mut out = ""
  let mut first = true
  for line in lines {
    if first {
      out = line
      first = false
    } else {
      out = out + "\n" + line
    }
  }
  out
}

///|
fn merge_notes_cat_sort_uniq(ours : String, theirs : String) -> String {
  let lines : Array[String] = []
  for line in split_lines(ours) {
    if line != "" {
      lines.push(line)
    }
  }
  for line in split_lines(theirs) {
    if line != "" {
      lines.push(line)
    }
  }
  if lines.length() == 0 {
    return ""
  }
  lines.sort()
  let uniq : Array[String] = []
  let mut prev : String? = None
  for line in lines {
    match prev {
      Some(p) if p == line => ()
      _ => {
        uniq.push(line)
        prev = Some(line)
      }
    }
  }
  join_lines(uniq)
}

///|
fn split_whitespace_tokens(line : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut current = StringBuilder::new()
  let mut in_token = false
  for c in line {
    if c == ' ' || c == '\t' {
      if in_token {
        tokens.push(current.to_string())
        current = StringBuilder::new()
        in_token = false
      }
    } else {
      current.write_char(c)
      in_token = true
    }
  }
  if in_token {
    tokens.push(current.to_string())
  }
  tokens
}

///|
async fn notes_merge(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  other_ref_path : String,
  strategy : String?,
) -> Unit raise Error {
  let current = load_notes_tree(rfs, git_dir, notes_ref_path)
  let other = load_notes_tree(rfs, git_dir, other_ref_path)
  guard other is Some((other_commit_id, other_entries)) else {
    @stdio.stderr.write("error: no notes found to merge")
    @sys.exit(1)
  }
  match current {
    None => {
      wfs.mkdir_p(git_dir + "/refs/notes")
      wfs.write_string(notes_ref_path, other_commit_id.to_hex() + "\n")
      return
    }
    Some((current_commit_id, current_entries)) => {
      let db = @bitlib.ObjectDb::load(rfs, git_dir)
      let entries : Map[String, @bitcore.TreeEntry] = Map::new()
      for e in current_entries {
        entries.set(e.name, e)
      }
      let mut conflicts = 0
      for e in other_entries {
        match entries.get(e.name) {
          None => entries.set(e.name, e)
          Some(existing) =>
            if existing.id == e.id {
              ()
            } else if strategy == Some("theirs") {
              entries.set(e.name, e)
            } else if strategy == Some("ours") {
              ()
            } else if strategy == Some("union") {
              let ours = note_text(db, rfs, existing)
              let theirs = note_text(db, rfs, e)
              let merged = merge_notes_union(ours, theirs)
              let merged_content = Bytes::from_array(
                merged.to_array().map(c => c.to_int().to_byte()),
              )
              let merged_id = @bitlib.write_loose_object(
                wfs,
                git_dir,
                @bitcore.ObjectType::Blob,
                merged_content,
              )
              entries.set(
                e.name,
                @bitcore.TreeEntry::new("100644", e.name, merged_id),
              )
            } else if strategy == Some("cat_sort_uniq") {
              let ours = note_text(db, rfs, existing)
              let theirs = note_text(db, rfs, e)
              let merged = merge_notes_cat_sort_uniq(ours, theirs)
              let merged_content = Bytes::from_array(
                merged.to_array().map(c => c.to_int().to_byte()),
              )
              let merged_id = @bitlib.write_loose_object(
                wfs,
                git_dir,
                @bitcore.ObjectType::Blob,
                merged_content,
              )
              entries.set(
                e.name,
                @bitcore.TreeEntry::new("100644", e.name, merged_id),
              )
            } else {
              conflicts += 1
            }
        }
      }
      if conflicts > 0 {
        @stdio.stderr.write("error: notes merge conflict")
        @sys.exit(1)
      }
      let merged_entries : Array[@bitcore.TreeEntry] = []
      entries.each((_k, v) => merged_entries.push(v))
      merged_entries.sort_by((a, b) => a.name.compare(b.name))
      let (tree_id, tree_data) = @bitcore.create_tree(merged_entries)
      @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
      let author = get_author_string()
      let timestamp = get_current_timestamp()
      let current_hex = current_commit_id.to_hex()
      let other_hex = other_commit_id.to_hex()
      let parents = if current_hex == other_hex {
        [current_commit_id]
      } else {
        [current_commit_id, other_commit_id]
      }
      let commit = @bitcore.Commit::new(
        tree_id, parents, author, timestamp, "+0000", author, timestamp, "+0000",
        "Notes merged by 'git notes merge'\n",
      )
      let (new_commit_id, commit_data) = @bitcore.create_commit(commit)
      @bitlib.write_object_bytes(wfs, git_dir, new_commit_id, commit_data)
      wfs.mkdir_p(git_dir + "/refs/notes")
      wfs.write_string(notes_ref_path, new_commit_id.to_hex() + "\n")
    }
  }
}

///|
async fn notes_rewrite(
  wfs : &@bitcore.FileSystem,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  notes_ref_path : String,
  from_ref : String,
  to_ref : String,
  force : Bool,
) -> Unit raise Error {
  let from_id = @bitrepo.rev_parse(rfs, git_dir, from_ref)
  guard from_id is Some(fid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{from_ref}")
  }
  let to_id = @bitrepo.rev_parse(rfs, git_dir, to_ref)
  guard to_id is Some(tid) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{to_ref}")
  }
  let from_hex = fid.to_hex()
  let to_hex = tid.to_hex()
  if from_hex == to_hex {
    return
  }
  let current = load_notes_tree(rfs, git_dir, notes_ref_path)
  guard current is Some((current_commit_id, current_entries)) else { return }
  let entries : Map[String, @bitcore.TreeEntry] = Map::new()
  let mut source : @bitcore.TreeEntry? = None
  let mut dest_exists = false
  for e in current_entries {
    if e.name == from_hex {
      source = Some(e)
    } else if e.name == to_hex {
      dest_exists = true
      entries.set(e.name, e)
    } else {
      entries.set(e.name, e)
    }
  }
  guard source is Some(src) else { return }
  if dest_exists && not(force) {
    @stdio.stderr.write("error: note already exists for \{to_hex}")
    @sys.exit(1)
  }
  entries.remove(from_hex)
  entries.set(to_hex, @bitcore.TreeEntry::new("100644", to_hex, src.id))
  let rewritten_entries : Array[@bitcore.TreeEntry] = []
  entries.each((_k, v) => rewritten_entries.push(v))
  rewritten_entries.sort_by((a, b) => a.name.compare(b.name))
  let (tree_id, tree_data) = @bitcore.create_tree(rewritten_entries)
  @bitlib.write_object_bytes(wfs, git_dir, tree_id, tree_data)
  let author = get_author_string()
  let timestamp = get_current_timestamp()
  let commit = @bitcore.Commit::new(
    tree_id,
    [current_commit_id],
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    "Notes rewritten by 'git notes rewrite'\n",
  )
  let (new_commit_id, commit_data) = @bitcore.create_commit(commit)
  @bitlib.write_object_bytes(wfs, git_dir, new_commit_id, commit_data)
  wfs.mkdir_p(git_dir + "/refs/notes")
  wfs.write_string(notes_ref_path, new_commit_id.to_hex() + "\n")
}

///|
/// Handle git bisect command
