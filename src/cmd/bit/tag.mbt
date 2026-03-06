///|
async fn handle_tag(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let mut list_mode = false
  let mut explicit_list = false
  let mut delete_mode = false
  let mut annotated = false
  let mut force = false
  let mut ignore_case = false
  let delete_tags : Array[String] = []
  let mut message : String? = None
  let mut tag_name : String? = None
  let mut target : String? = None
  let patterns : Array[String] = []
  let sort_keys : Array[String] = []
  let points_at : Array[String] = []
  let mut verify_mode = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" => {
        print_line(
          "usage: git tag [-a | -d | -l | -v] [-f] [-i] [-m <msg>] [-s] [<tagname>] [<head>]",
        )
        @sys.exit(129)
        return
      }
      "-l" | "--list" => {
        list_mode = true
        explicit_list = true
      }
      "-d" | "--delete" => delete_mode = true
      "-a" | "--annotate" => annotated = true
      "-f" | "--force" => force = true
      "-i" | "--ignore-case" => ignore_case = true
      "-v" | "--verify" => verify_mode = true
      "-n" if i + 1 < args.length() =>
        // -n<num> show N lines of annotation; skip
        i += 1
      _ if arg.has_prefix("-n") => ()
      "-m" if i + 1 < args.length() => {
        message = Some(args[i + 1])
        annotated = true
        i += 2
        continue
      }
      _ if arg.has_prefix("-m") => {
        message = Some((try! arg[2:]).to_string())
        annotated = true
        i += 1
        continue
      }
      _ if arg.has_prefix("--message=") => {
        message = Some((try! arg[10:]).to_string())
        annotated = true
        i += 1
        continue
      }
      "--sort" if i + 1 < args.length() => {
        sort_keys.push(args[i + 1])
        i += 2
        continue
      }
      _ if arg.has_prefix("--sort=") =>
        sort_keys.push(String::unsafe_substring(arg, start=7, end=arg.length()))
      _ if arg.has_prefix("--points-at=") =>
        points_at.push(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      "--points-at" if i + 1 < args.length() => {
        points_at.push(args[i + 1])
        i += 2
        continue
      }
      "--contains"
      | "--no-contains"
      | "--merged"
      | "--no-merged"
      | "--color"
      | "--no-color"
      | "--column"
      | "--no-column" => ()
      _ if arg.has_prefix("--contains=") ||
        arg.has_prefix("--no-contains=") ||
        arg.has_prefix("--merged=") ||
        arg.has_prefix("--no-merged=") ||
        arg.has_prefix("--format=") ||
        arg.has_prefix("--color=") => ()
      _ if not(arg.has_prefix("-")) =>
        if delete_mode {
          delete_tags.push(arg)
        } else if explicit_list {
          patterns.push(arg)
        } else if tag_name is None {
          tag_name = Some(arg)
        } else if target is None {
          target = Some(arg)
        }
      "-s" | "--sign" => annotated = true
      _ if arg.has_prefix("-") => warn_unimplemented_arg("tag", arg)
      _ => ()
    }
    i += 1
  }
  // Determine list mode: if no create/delete args, default to list
  if not(delete_mode) && not(annotated) && message is None && not(verify_mode) {
    if tag_name is None {
      list_mode = true
    } else if explicit_list {
      // -l with pattern: tag_name is actually a pattern
      match tag_name {
        Some(name) => {
          patterns.push(name)
          tag_name = None
        }
        None => ()
      }
      list_mode = true
    }
  }
  if explicit_list && tag_name is Some(name) {
    patterns.push(name)
    tag_name = None
    list_mode = true
  }
  ignore(verify_mode)
  if delete_mode {
    guard delete_tags.length() > 0 else {
      raise @bitcore.GitError::InvalidObject("tag name required for delete")
    }
    for name in delete_tags {
      let id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name)
      @bitlib.delete_tag(fs, git_dir, name)
      match id {
        Some(oid) =>
          eprint_line(
            "Deleted tag '\{name}' (was \{(try! oid.to_hex()[:7]).to_string()})",
          )
        None => eprint_line("Deleted tag '\{name}'")
      }
    }
    return ()
  }
  if list_mode {
    let tags = @bitlib.list_tags(fs, git_dir)
    // Filter by patterns (glob matching)
    let filtered : Array[String] = if patterns.length() > 0 {
      let result : Array[String] = []
      for tag in tags {
        let mut matched = false
        for pattern in patterns {
          if tag_glob_match(pattern, tag, ignore_case) {
            matched = true
            break
          }
        }
        if matched {
          result.push(tag)
        }
      }
      result
    } else {
      tags
    }
    // Filter by --points-at
    let final_tags : Array[String] = if points_at.length() > 0 {
      let result : Array[String] = []
      for tag in filtered {
        let tag_id = @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + tag)
        match tag_id {
          Some(tid) => {
            let mut matches = false
            for target in points_at {
              match @bitrepo.rev_parse(fs, git_dir, target) {
                Some(pid) if pid.to_hex() == tid.to_hex() => matches = true
                _ => ()
              }
            }
            if matches {
              result.push(tag)
            }
          }
          None => ()
        }
      }
      result
    } else {
      filtered
    }
    // Sort
    if sort_keys.length() > 0 {
      for key in sort_keys {
        let descending = key.has_prefix("-")
        let sort_field = if descending {
          String::unsafe_substring(key, start=1, end=key.length())
        } else {
          key
        }
        final_tags.sort_by(fn(a, b) {
          let cmp = tag_sort_compare(a, b, sort_field, ignore_case)
          if descending {
            -cmp
          } else {
            cmp
          }
        })
      }
    } else {
      final_tags.sort()
    }
    for tag in final_tags {
      print_line(tag)
    }
    return ()
  }
  guard tag_name is Some(name) else {
    raise @bitcore.GitError::InvalidObject("tag name required")
  }
  // Prohibit HEAD as tag name
  if name == "HEAD" {
    eprint_line("fatal: 'HEAD' is not a valid tag name")
    @sys.exit(128)
    return
  }
  // Resolve target (default to HEAD)
  let target_ref = target.unwrap_or("HEAD")
  let commit_id = @bitrepo.rev_parse(fs, git_dir, target_ref)
  guard commit_id is Some(id) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{target_ref}")
  }
  if force {
    if @bitlib.resolve_ref(fs, git_dir, "refs/tags/" + name) is Some(_) {
      @bitlib.delete_tag(fs, git_dir, name)
    }
  }
  if annotated {
    let msg = message.unwrap_or("")
    let author = get_author_string()
    let timestamp = get_commit_timestamp()
    let timezone = get_commit_timezone()
    @bitlib.create_annotated_tag(
      fs,
      fs,
      git_dir,
      name,
      id,
      msg,
      author,
      timestamp,
      timezone~,
    )
  } else {
    @bitlib.create_lightweight_tag(fs, git_dir, name, id)
  }
}

///|
fn tag_glob_match(pattern : String, text : String, ignore_case : Bool) -> Bool {
  let p = if ignore_case { pattern.to_lower() } else { pattern }
  let t = if ignore_case { text.to_lower() } else { text }
  tag_glob_match_impl(p, t)
}

///|
fn tag_glob_match_impl(pattern : String, text : String) -> Bool {
  let p = pattern.to_array()
  let t = text.to_array()
  let plen = p.length()
  let tlen = t.length()
  let mut pi = 0
  let mut ti = 0
  let mut star_pi = -1
  let mut star_ti = -1
  while ti < tlen {
    if pi < plen && (p[pi] == t[ti] || p[pi] == '?') {
      pi += 1
      ti += 1
    } else if pi < plen && p[pi] == '*' {
      star_pi = pi
      star_ti = ti
      pi += 1
    } else if star_pi >= 0 {
      pi = star_pi + 1
      star_ti += 1
      ti = star_ti
    } else {
      return false
    }
  }
  while pi < plen && p[pi] == '*' {
    pi += 1
  }
  pi == plen
}

///|
fn tag_sort_compare(
  a : String,
  b : String,
  field : String,
  _ignore_case : Bool,
) -> Int {
  match field {
    "refname" | "refname:short" => a.compare(b)
    _ if field.has_prefix("version:refname") || field == "v:refname" =>
      tag_version_compare(a, b)
    _ => a.compare(b)
  }
}

///|
fn tag_version_compare(a : String, b : String) -> Int {
  // Basic version comparison
  a.compare(b)
}

///|
