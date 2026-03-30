///| git fast-export — Output a fast-import-compatible stream

///|
async fn handle_fast_export(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let git_dir = resolve_git_dir(fs, root)
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Parse options
  let mut all = false
  let mut show_original_ids = false
  let mut full_tree = false
  let mut no_data = false
  let mut signed_tags = "warn-strip"
  let mut tag_of_filtered_object = "abort"
  let mut import_marks_file : String? = None
  let mut export_marks_file : String? = None
  let refspec_filters : Array[String] = []
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git fast-export [<options>] [<rev-list-args>]",
          summary="Output a fast-import-compatible stream.",
        )
        return
      }
      "--all" => all = true
      "--show-original-ids" => show_original_ids = true
      "--full-tree" => full_tree = true
      "--no-data" => no_data = true
      _ if arg.has_prefix("--signed-tags=") =>
        signed_tags = arg[14:].to_string()
      _ if arg.has_prefix("--tag-of-filtered-object=") =>
        tag_of_filtered_object = arg[25:].to_string()
      _ if arg.has_prefix("--import-marks=") =>
        import_marks_file = Some(arg[15:].to_string())
      _ if arg.has_prefix("--export-marks=") =>
        export_marks_file = Some(arg[15:].to_string())
      _ if arg.has_prefix("--refspec=") =>
        refspec_filters.push(arg[10:].to_string())
      "--" => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("fast-export", arg)
      _ => positional.push(arg)
    }
  }
  // Validate signed-tags option
  match signed_tags {
    "strip" | "warn-strip" | "verbatim" | "abort" | "warn" => ()
    _ => {
      eprint_line("fatal: Unknown signed-tags mode: \{signed_tags}")
      @sys.exit(1)
    }
  }
  // Validate tag-of-filtered-object option
  match tag_of_filtered_object {
    "abort" | "drop" | "rewrite" => ()
    _ => {
      eprint_line(
        "fatal: Unknown tag-of-filtered-object mode: \{tag_of_filtered_object}",
      )
      @sys.exit(1)
    }
  }
  // Collect refs
  let all_refs = @bitrepo.show_ref(fs, git_dir)
  let target_refs : Array[(String, @bitcore.ObjectId)] = []
  if all {
    for item in all_refs {
      target_refs.push(item)
    }
  } else if positional.length() > 0 {
    // Resolve positional args as refs
    for name in positional {
      match @bitlib.resolve_ref(fs, git_dir, name) {
        Some(id) => {
          let mut found = false
          for item in all_refs {
            if item.1 == id {
              target_refs.push(item)
              found = true
              break
            }
          }
          if !(found) {
            target_refs.push((name, id))
          }
        }
        None => {
          eprint_line("fatal: Not a valid ref: \{name}")
          @sys.exit(128)
        }
      }
    }
  } else {
    // Default: export HEAD
    match @bitlib.resolve_ref(fs, git_dir, "HEAD") {
      Some(id) => target_refs.push(("HEAD", id))
      None => {
        eprint_line("fatal: Could not resolve HEAD")
        @sys.exit(128)
      }
    }
  }
  // Apply refspec filters
  let filtered_refs : Array[(String, @bitcore.ObjectId)] = if refspec_filters.length() >
    0 {
    let out : Array[(String, @bitcore.ObjectId)] = []
    for item in target_refs {
      for filter in refspec_filters {
        if item.0.has_prefix(filter) {
          out.push(item)
          break
        }
      }
    }
    out
  } else {
    target_refs
  }
  // Load import marks if provided
  let mark_map : Map[String, Int] = {} // oid-hex -> mark
  let mut next_mark = 1
  if import_marks_file is Some(path) {
    let content = fs.read_file(path) catch { _ => b"" }
    let text = @utf8.decode_lossy(content[:])
    for line_view in text.split("\n") {
      let line = line_view.to_string()
      if line.length() > 0 && line[0] == ':' {
        let parts = fast_export_split_first_space(line[1:].to_string())
        if parts.0.length() > 0 && parts.1.length() > 0 {
          let mark_num = @string.parse_int(parts.0) catch { _ => 0 }
          if mark_num > 0 {
            mark_map[parts.1] = mark_num
            if mark_num >= next_mark {
              next_mark = mark_num + 1
            }
          }
        }
      }
    }
  }
  // Separate refs into branch refs and tag refs
  let branch_refs : Array[(String, @bitcore.ObjectId)] = []
  let tag_refs : Array[(String, @bitcore.ObjectId)] = []
  for item in filtered_refs {
    if item.0.has_prefix("refs/tags/") {
      tag_refs.push(item)
    } else {
      branch_refs.push(item)
    }
  }
  // Collect all reachable commits (BFS from all tips)
  let commit_tips : Array[@bitcore.ObjectId] = []
  for item in branch_refs {
    let id = fast_export_peel_to_commit(db, fs, item.1)
    commit_tips.push(id)
  }
  for item in tag_refs {
    let id = fast_export_peel_to_commit(db, fs, item.1)
    commit_tips.push(id)
  }
  // Topological sort via DFS post-order, then reverse for oldest-first
  let visited : Map[String, Bool] = {}
  let topo_order : Array[@bitcore.ObjectId] = []
  for tip in commit_tips {
    fast_export_topo_dfs(db, fs, tip, visited, topo_order)
  }
  let topo_order = topo_order.rev()
  // Output stream
  let buf = StringBuilder::new()
  let blob_marks : Map[String, Int] = {} // blob oid hex -> mark
  for oid_hex, mark_val in mark_map {
    blob_marks[oid_hex] = mark_val
  }
  // Process each commit
  for commit_id in topo_order {
    let obj = db.get(fs, commit_id) catch { _ => None }
    match obj {
      None => continue
      Some(commit_obj) => {
        if commit_obj.obj_type != @bitcore.ObjectType::Commit {
          continue
        }
        let info = @bitcore.parse_commit(commit_obj.data)
        let commit_text = @utf8.decode_lossy(commit_obj.data[:])
        let author_line = fast_export_extract_header(commit_text, "author")
        let committer_line = fast_export_extract_header(
          commit_text, "committer",
        )
        let message = fast_export_extract_message(commit_text)
        // Get tree files for this commit
        let tree_files = @bitlib.collect_tree_files(db, fs, info.tree)
        // Determine file operations (M/D)
        let file_ops : Array[String] = []
        if full_tree || info.parents.length() == 0 {
          // Full tree or root commit: output all files
          for path, file_entry in tree_files {
            let mode_str = fast_export_format_mode(file_entry.mode)
            if no_data {
              file_ops.push("M \{mode_str} \{file_entry.id.to_hex()} \{path}")
            } else {
              let blob_mark = fast_export_ensure_blob(
                db,
                fs,
                file_entry.id,
                blob_marks,
                buf,
                show_original_ids,
                next_mark,
              )
              next_mark = next_mark + blob_mark.1
              file_ops.push("M \{mode_str} :\{blob_mark.0} \{path}")
            }
          }
        } else {
          // Diff against first parent
          let parent_id = info.parents[0]
          let parent_obj = db.get(fs, parent_id) catch { _ => None }
          match parent_obj {
            Some(pobj) => {
              let parent_info = @bitcore.parse_commit(pobj.data)
              let parent_files = @bitlib.collect_tree_files(
                db,
                fs,
                parent_info.tree,
              )
              // Find modified/added files
              for path, file_entry in tree_files {
                let mode_str = fast_export_format_mode(file_entry.mode)
                let needs_output = match parent_files.get(path) {
                  Some(pe) =>
                    pe.id != file_entry.id || pe.mode != file_entry.mode
                  None => true
                }
                if needs_output {
                  if no_data {
                    file_ops.push(
                      "M \{mode_str} \{file_entry.id.to_hex()} \{path}",
                    )
                  } else {
                    let blob_mark = fast_export_ensure_blob(
                      db,
                      fs,
                      file_entry.id,
                      blob_marks,
                      buf,
                      show_original_ids,
                      next_mark,
                    )
                    next_mark = next_mark + blob_mark.1
                    file_ops.push("M \{mode_str} :\{blob_mark.0} \{path}")
                  }
                }
              }
              // Find deleted files
              for path, _entry in parent_files {
                if !(tree_files.contains(path)) {
                  file_ops.push("D \{path}")
                }
              }
            }
            None =>
              // Parent missing, treat as full tree
              for path, file_entry in tree_files {
                let mode_str = fast_export_format_mode(file_entry.mode)
                if no_data {
                  file_ops.push(
                    "M \{mode_str} \{file_entry.id.to_hex()} \{path}",
                  )
                } else {
                  let blob_mark = fast_export_ensure_blob(
                    db,
                    fs,
                    file_entry.id,
                    blob_marks,
                    buf,
                    show_original_ids,
                    next_mark,
                  )
                  next_mark = next_mark + blob_mark.1
                  file_ops.push("M \{mode_str} :\{blob_mark.0} \{path}")
                }
              }
          }
        }
        // Assign mark to this commit
        let commit_hex = commit_id.to_hex()
        let commit_mark = match mark_map.get(commit_hex) {
          Some(m) => m
          None => {
            let m = next_mark
            next_mark = next_mark + 1
            mark_map[commit_hex] = m
            m
          }
        }
        // Find which ref this commit belongs to
        let ref_name = fast_export_find_ref_for_commit(branch_refs, commit_id)
        // Write commit command
        buf.write_string("commit \{ref_name}\n")
        buf.write_string("mark :\{commit_mark}\n")
        if show_original_ids {
          buf.write_string("original-oid \{commit_hex}\n")
        }
        if author_line.length() > 0 {
          buf.write_string("author \{author_line}\n")
        }
        if committer_line.length() > 0 {
          buf.write_string("committer \{committer_line}\n")
        }
        let msg_bytes = @utf8.encode(message)
        buf.write_string("data \{msg_bytes.length()}\n")
        buf.write_string(message)
        if !(message.has_suffix("\n")) {
          buf.write_string("\n")
        }
        // from (first parent)
        if info.parents.length() > 0 {
          let parent_hex = info.parents[0].to_hex()
          match mark_map.get(parent_hex) {
            Some(parent_mark) => buf.write_string("from :\{parent_mark}\n")
            None => ()
          }
        }
        // merge (additional parents)
        for i in 1..<info.parents.length() {
          let parent_hex = info.parents[i].to_hex()
          match mark_map.get(parent_hex) {
            Some(parent_mark) => buf.write_string("merge :\{parent_mark}\n")
            None => ()
          }
        }
        // File operations
        for op in file_ops {
          buf.write_string(op)
          buf.write_string("\n")
        }
        buf.write_string("\n")
        // Flush periodically to avoid huge buffer
        if buf.to_string().length() > 65536 {
          print_str(buf.to_string())
          buf.reset()
        }
      }
    }
  }
  // Output tags
  for item in tag_refs {
    let (refname, tag_id) = item
    let tag_name = if refname.has_prefix("refs/tags/") {
      refname[10:].to_string()
    } else {
      refname
    }
    let obj = db.get(fs, tag_id) catch { _ => None }
    match obj {
      Some(tag_obj) =>
        if tag_obj.obj_type == @bitcore.ObjectType::Tag {
          let tag_text = @utf8.decode_lossy(tag_obj.data[:])
          // Check for signature
          let has_sig = tag_text.contains("-----BEGIN PGP SIGNATURE-----") ||
            tag_text.contains("-----BEGIN SSH SIGNATURE-----")
          if has_sig &&
            (
              signed_tags == "abort" ||
              signed_tags == "strip" ||
              signed_tags == "warn-strip"
            ) {
            if signed_tags == "abort" {
              eprint_line(
                "fatal: Encountered signed tag \{tag_name}; use --signed-tags=<mode> to handle it.",
              )
              @sys.exit(1)
            }
            if signed_tags == "warn-strip" || signed_tags == "warn" {
              eprint_line("warning: Stripping signature from tag \{tag_name}")
            }
          }
          // Find target commit mark
          let target_hex = fast_export_extract_header(tag_text, "object")
          match mark_map.get(target_hex) {
            Some(target_mark) => {
              let tagger_line = fast_export_extract_header(tag_text, "tagger")
              let tag_message = fast_export_extract_message(tag_text)
              buf.write_string("tag \{tag_name}\n")
              buf.write_string("from :\{target_mark}\n")
              if show_original_ids {
                buf.write_string("original-oid \{tag_id.to_hex()}\n")
              }
              if tagger_line.length() > 0 {
                buf.write_string("tagger \{tagger_line}\n")
              }
              let tag_msg_bytes = @utf8.encode(tag_message)
              buf.write_string("data \{tag_msg_bytes.length()}\n")
              buf.write_string(tag_message)
              if !(tag_message.has_suffix("\n")) {
                buf.write_string("\n")
              }
              buf.write_string("\n")
            }
            None =>
              if tag_of_filtered_object != "drop" {
                buf.write_string("reset \{refname}\n")
                buf.write_string("from \{target_hex}\n")
                buf.write_string("\n")
              }
          }
        } else {
          // Lightweight tag pointing to non-tag object
          let target_hex = tag_id.to_hex()
          match mark_map.get(target_hex) {
            Some(target_mark) => {
              buf.write_string("reset \{refname}\n")
              buf.write_string("from :\{target_mark}\n")
              buf.write_string("\n")
            }
            None => ()
          }
        }
      None => ()
    }
  }
  // Output resets for branch heads
  for item in branch_refs {
    let (refname, ref_id) = item
    let commit_id = fast_export_peel_to_commit(db, fs, ref_id)
    let commit_hex = commit_id.to_hex()
    match mark_map.get(commit_hex) {
      Some(mark) => {
        buf.write_string("reset \{refname}\n")
        buf.write_string("from :\{mark}\n")
        buf.write_string("\n")
      }
      None => ()
    }
  }
  // Write export marks file if requested
  if export_marks_file is Some(path) {
    let marks_buf = StringBuilder::new()
    for oid_hex, mark_val in mark_map {
      marks_buf.write_string(":\{mark_val} \{oid_hex}\n")
    }
    fs.write_file(path, str_to_bytes(marks_buf.to_string()))
  }
  // Flush remaining output
  let remaining = buf.to_string()
  if remaining.length() > 0 {
    print_str(remaining)
  }
}

///|
fn fast_export_split_first_space(s : String) -> (String, String) {
  for i in 0..<s.length() {
    if s[i] == ' ' {
      return (
        String::unsafe_substring(s, start=0, end=i),
        String::unsafe_substring(s, start=i + 1, end=s.length()),
      )
    }
  }
  (s, "")
}

///|
fn fast_export_extract_header(text : String, header : String) -> String {
  let prefix = header + " "
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      break
    }
    if line.has_prefix(prefix) {
      return String::unsafe_substring(
        line,
        start=prefix.length(),
        end=line.length(),
      )
    }
  }
  ""
}

///|
fn fast_export_extract_message(text : String) -> String {
  let len = text.length()
  for i in 0..<(len - 1) {
    if text[i] == '\n' && text[i + 1] == '\n' {
      return String::unsafe_substring(text, start=i + 2, end=len)
    }
  }
  ""
}

///|
fn fast_export_format_mode(mode : Int) -> String {
  match mode {
    0o100644 => "100644"
    0o100755 => "100755"
    0o120000 => "120000"
    0o040000 => "040000"
    0o160000 => "160000"
    _ => {
      let mut n = mode
      if n == 0 {
        return "0"
      }
      let digits : Array[Char] = []
      while n > 0 {
        let d = n % 8
        digits.push((d + 48).unsafe_to_char())
        n = n / 8
      }
      String::from_array(digits.rev())
    }
  }
}

///|
fn fast_export_peel_to_commit(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId {
  let mut current = id
  for _ in 0..<10 {
    let obj = db.get(fs, current) catch { _ => return current }
    match obj {
      None => return current
      Some(o) =>
        match o.obj_type {
          @bitcore.ObjectType::Commit => return current
          @bitcore.ObjectType::Tag => {
            let text = @utf8.decode_lossy(o.data[:])
            let target = fast_export_extract_header(text, "object")
            if target.length() == 40 {
              current = @bitcore.ObjectId::from_hex(target) catch {
                _ => return current
              }
            } else {
              return current
            }
          }
          _ => return current
        }
    }
  }
  current
}

///|
fn fast_export_topo_dfs(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  id : @bitcore.ObjectId,
  visited : Map[String, Bool],
  order : Array[@bitcore.ObjectId],
) -> Unit {
  let hex = id.to_hex()
  if visited.contains(hex) {
    return
  }
  visited[hex] = true
  let obj = db.get(fs, id) catch { _ => return }
  match obj {
    None => ()
    Some(o) =>
      if o.obj_type == @bitcore.ObjectType::Commit {
        let info = @bitcore.parse_commit(o.data) catch { _ => return }
        for parent in info.parents {
          fast_export_topo_dfs(db, fs, parent, visited, order)
        }
        order.push(id)
      }
  }
}

///|
/// Returns (mark_id, marks_consumed) where marks_consumed is 0 if blob was
/// already emitted, 1 if a new mark was allocated.
fn fast_export_ensure_blob(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  blob_id : @bitcore.ObjectId,
  blob_marks : Map[String, Int],
  buf : StringBuilder,
  show_original_ids : Bool,
  next_mark : Int,
) -> (Int, Int) {
  let hex = blob_id.to_hex()
  match blob_marks.get(hex) {
    Some(mark) => (mark, 0)
    None => {
      let mark = next_mark
      blob_marks[hex] = mark
      // Output blob
      let obj = db.get(fs, blob_id) catch { _ => None }
      match obj {
        Some(blob_obj) => {
          buf.write_string("blob\n")
          buf.write_string("mark :\{mark}\n")
          if show_original_ids {
            buf.write_string("original-oid \{hex}\n")
          }
          buf.write_string("data \{blob_obj.data.length()}\n")
          buf.write_string(@utf8.decode_lossy(blob_obj.data[:]))
          buf.write_string("\n")
        }
        None => ()
      }
      (mark, 1)
    }
  }
}

///|
fn fast_export_find_ref_for_commit(
  refs : Array[(String, @bitcore.ObjectId)],
  commit_id : @bitcore.ObjectId,
) -> String {
  for item in refs {
    if item.1 == commit_id {
      return item.0
    }
  }
  if refs.length() > 0 {
    return refs[0].0
  }
  "refs/heads/master"
}
