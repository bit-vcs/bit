///|
async fn handle_stash(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  check_and_exit_unsupported_attrs(root)
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  // Determine subcommand (default: push if args are empty or start with -)
  let subcmd = if args.length() == 0 {
    "push"
  } else {
    let first = args[0]
    if first.has_prefix("-") {
      "push"
    } else {
      first
    }
  }
  let rest : Array[String] = if args.length() > 0 && !args[0].has_prefix("-") {
    args.iter().drop(1).collect()
  } else {
    args.iter().collect()
  }
  match subcmd {
    "push" | "save" => {
      // Parse message option
      let mut message = ""
      let mut i = 0
      while i < rest.length() {
        let arg = rest[i]
        match arg {
          "-m" | "--message" if i + 1 < rest.length() => {
            message = rest[i + 1]
            i += 2
            continue
          }
          _ => ()
        }
        i += 1
      }
      let author = get_author_string()
      let timestamp = get_commit_timestamp()
      let result = @bitlib.stash_push(fs, fs, root, message, author, timestamp)
      match result {
        Some(id) => {
          let short = String::unsafe_substring(id.to_hex(), start=0, end=7)
          print_line("Saved working directory and index state [\{short}]")
        }
        None => print_line("No local changes to save")
      }
    }
    "list" => {
      let entries = @bitlib.stash_list(fs, git_dir)
      for i, entry in entries {
        let short = String::unsafe_substring(entry.id.to_hex(), start=0, end=7)
        print_line("stash@{" + i.to_string() + "}: \{entry.message} [\{short}]")
      }
    }
    "pop" => {
      let index = parse_stash_index(rest)
      @bitlib.stash_apply(fs, fs, root, index, true)
      print_line("Dropped stash@{" + index.to_string() + "}")
    }
    "apply" => {
      let index = parse_stash_index(rest)
      @bitlib.stash_apply(fs, fs, root, index, false)
      print_line("Applied stash@{" + index.to_string() + "}")
    }
    "drop" => {
      let index = parse_stash_index(rest)
      @bitlib.stash_drop(fs, fs, root, index)
      print_line("Dropped stash@{" + index.to_string() + "}")
    }
    "show" => {
      let index = parse_stash_index(rest)
      let (stash_info, db) = stash_load_commit(fs, git_dir, index)
      let parent_id = stash_info.parents[0]
      let parent_obj = db.get(fs, parent_id) catch { _ => None }
      let parent_tree = match parent_obj {
        Some(po) => @bitcore.parse_commit(po.data).tree
        None =>
          raise @bitcore.GitError::InvalidObject("Cannot read stash parent")
      }
      let parent_files = @bitlib.collect_tree_files(db, fs, parent_tree)
      let stash_files = @bitlib.collect_tree_files(db, fs, stash_info.tree)
      // Check if --stat or -p was requested
      let mut stat_mode = true
      for arg in rest {
        if arg == "-p" || arg == "--patch" || arg == "-u" {
          stat_mode = false
        }
      }
      if stat_mode {
        stash_show_stat(parent_files, stash_files)
      } else {
        stash_show_patch(db, fs, parent_files, stash_files)
      }
    }
    "create" | "store" => warn_unimplemented_arg("stash", subcmd)
    "branch" => {
      if rest.length() == 0 {
        eprint_line("usage: git stash branch <branchname> [<stash>]")
        @sys.exit(1)
      }
      let branch_name = rest[0]
      let index = if rest.length() > 1 {
        parse_stash_index(rest.iter().drop(1).collect())
      } else {
        0
      }
      let (stash_info, _db) = stash_load_commit(fs, git_dir, index)
      if stash_info.parents.length() > 0 {
        let parent_id = stash_info.parents[0]
        let ref_path = git_dir + "/refs/heads/" + branch_name
        @fs.write_string_to_file(ref_path, parent_id.to_hex() + "\n")
        let head_path = git_dir + "/HEAD"
        @fs.write_string_to_file(
          head_path,
          "ref: refs/heads/" + branch_name + "\n",
        )
        @bitlib.stash_apply(fs, fs, root, index, true)
        print_line(
          "Switched to a new branch '\{branch_name}' and applied stash@{\{index}}",
        )
      }
    }
    "clear" => {
      fs.remove_file(git_dir + "/refs/stash") catch {
        _ => ()
      }
      fs.remove_file(git_dir + "/logs/refs/stash") catch {
        _ => ()
      }
    }
    _ =>
      raise @bitcore.GitError::InvalidObject(
        "Unknown stash subcommand: \{subcmd}",
      )
  }
}

///|
fn parse_stash_index(args : Array[String]) -> Int {
  for arg in args {
    if arg.has_prefix("stash@{") && arg.has_suffix("}") {
      let num_str = String::unsafe_substring(arg, start=7, end=arg.length() - 1)
      let n = @string.parse_int(num_str) catch { _ => continue }
      return n
    }
    let n = @string.parse_int(arg) catch { _ => continue }
    return n
  }
  0
}

///|
/// Load stash commit info and ObjectDb. Shared by "show" and "branch".
fn stash_load_commit(
  fs : OsFs,
  git_dir : String,
  index : Int,
) -> (@bitcore.CommitInfo, @bitlib.ObjectDb) raise Error {
  let entries = @bitlib.stash_list(fs, git_dir)
  if index >= entries.length() {
    raise @bitcore.GitError::InvalidObject("No stash entry at index \{index}")
  }
  let stash_id = entries[index].id
  let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
  let stash_obj = db.get(fs, stash_id) catch {
    _ => raise @bitcore.GitError::InvalidObject("Cannot read stash commit")
  }
  match stash_obj {
    None => raise @bitcore.GitError::InvalidObject("Stash commit not found")
    Some(obj) => {
      let info = @bitcore.parse_commit(obj.data)
      if info.parents.length() == 0 {
        raise @bitcore.GitError::InvalidObject("Stash commit has no parent")
      }
      (info, db)
    }
  }
}

///|
/// Collect sorted union of paths from two tree file maps.
fn stash_collect_paths(
  parent_files : Map[String, @bitlib.TreeFileEntry],
  stash_files : Map[String, @bitlib.TreeFileEntry],
) -> Array[String] {
  @bitlib.stash_collect_paths(parent_files, stash_files)
}

///|
async fn stash_show_stat(
  parent_files : Map[String, @bitlib.TreeFileEntry],
  stash_files : Map[String, @bitlib.TreeFileEntry],
) -> Unit {
  let mut changed = 0
  let mut insertions = 0
  let mut deletions = 0
  let paths = stash_collect_paths(parent_files, stash_files)
  for path in paths {
    let in_parent = parent_files.contains(path)
    let in_stash = stash_files.contains(path)
    if in_parent && in_stash {
      let p = parent_files[path]
      let s = stash_files[path]
      if p.id.to_hex() != s.id.to_hex() {
        changed += 1
        insertions += 1
        deletions += 1
        print_line(" \{path} | 2 +-")
      }
    } else if in_stash {
      changed += 1
      insertions += 1
      print_line(" \{path} | 1 +")
    } else {
      changed += 1
      deletions += 1
      print_line(" \{path} | 1 -")
    }
  }
  let file_s = if changed != 1 { "s" } else { "" }
  let ins_s = if insertions != 1 { "s" } else { "" }
  let del_s = if deletions != 1 { "s" } else { "" }
  print_line(
    " \{changed} file\{file_s} changed, \{insertions} insertion\{ins_s}(+), \{deletions} deletion\{del_s}(-)",
  )
}

///|
async fn stash_show_patch(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  parent_files : Map[String, @bitlib.TreeFileEntry],
  stash_files : Map[String, @bitlib.TreeFileEntry],
) -> Unit {
  let paths = stash_collect_paths(parent_files, stash_files)
  for path in paths {
    let in_parent = parent_files.contains(path)
    let in_stash = stash_files.contains(path)
    if in_parent && in_stash {
      let p = parent_files[path]
      let s = stash_files[path]
      if p.id.to_hex() == s.id.to_hex() {
        continue
      }
      print_line("diff --git a/\{path} b/\{path}")
      let p_short = p.id.to_hex()[:7].to_string()
      let s_short = s.id.to_hex()[:7].to_string()
      print_line("index \{p_short}..\{s_short} \{stash_mode_str(s.mode)}")
      print_line("--- a/\{path}")
      print_line("+++ b/\{path}")
      let old_content = stash_read_blob(db, fs, p.id)
      let new_content = stash_read_blob(db, fs, s.id)
      stash_print_unified_diff(old_content, new_content)
    } else if in_stash {
      let s = stash_files[path]
      print_line("diff --git a/\{path} b/\{path}")
      print_line("new file mode \{stash_mode_str(s.mode)}")
      print_line("--- /dev/null")
      print_line("+++ b/\{path}")
      let content = stash_read_blob(db, fs, s.id)
      for line in content {
        print_line("+\{line}")
      }
    } else {
      let p = parent_files[path]
      print_line("diff --git a/\{path} b/\{path}")
      print_line("deleted file mode \{stash_mode_str(p.mode)}")
      print_line("--- a/\{path}")
      print_line("+++ /dev/null")
      let content = stash_read_blob(db, fs, p.id)
      for line in content {
        print_line("-\{line}")
      }
    }
  }
}

///|
fn stash_read_blob(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  id : @bitcore.ObjectId,
) -> Array[String] {
  let obj = db.get(fs, id) catch { _ => return [] }
  match obj {
    None => []
    Some(o) => {
      let text = @utf8.decode_lossy(o.data[:])
      let lines : Array[String] = []
      for line_view in text.split("\n") {
        lines.push(line_view.to_string())
      }
      if lines.length() > 0 && lines[lines.length() - 1] == "" {
        ignore(lines.pop())
      }
      lines
    }
  }
}

///|
fn stash_mode_str(mode : Int) -> String {
  @bitlib.stash_mode_str(mode)
}

///|
async fn stash_print_unified_diff(
  old_lines : Array[String],
  new_lines : Array[String],
) -> Unit {
  if old_lines.length() == 0 && new_lines.length() == 0 {
    return
  }
  print_line("@@ -1,\{old_lines.length()} +1,\{new_lines.length()} @@")
  for line in old_lines {
    print_line("-\{line}")
  }
  for line in new_lines {
    print_line("+\{line}")
  }
}

///|
/// Show branches and their commits (git show-branch)
