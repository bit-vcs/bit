///|
/// git last-modified: Show which commit last modified each path.
///
/// EXPERIMENTAL plumbing command (git 2.55). Thin CLI wrapper around
/// `@bitlib.last_modified_compute`. Output format:
///   <oid> TAB <path> LF        (or NUL with -z); boundary commits prefixed `^`.

///|
/// Index of the first `..` (range separator) in `s`, or None.
fn lm_find_range_sep(s : String) -> Int? {
  let mut k = 0
  while k + 1 < s.length() {
    if s[k] == '.' && s[k + 1] == '.' {
      return Some(k)
    }
    k += 1
  }
  None
}

///|
fn lm_is_all_digits(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  for c in s {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
async fn handle_last_modified(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)

  // -- parse arguments ------------------------------------------------------
  let mut max_depth = 0
  let mut show_trees = false
  let mut nul = false
  let mut max_count = -1
  let mut rev_spec : String? = None
  let pathspecs : Array[String] = []
  let bottoms : Array[@bitcore.ObjectId] = []
  let mut only_positional = false
  // Pathspecs are interpreted relative to the current directory.
  let cwd_prefix = compute_cwd_prefix(root)
  fn add_pathspec(arg : String) -> Unit {
    if cwd_prefix.length() == 0 {
      pathspecs.push(arg)
    } else {
      pathspecs.push(cwd_prefix + "/" + arg)
    }
  }

  fn set_rev(spec : String) -> Unit raise Error {
    if rev_spec is Some(_) {
      raise @bitcore.GitError::InvalidObject(
        "last-modified can only operate on one commit at a time",
      )
    }
    rev_spec = Some(spec)
  }

  fn resolve_rev(spec : String) -> @bitcore.ObjectId raise Error {
    guard @bitrepo.rev_parse(rfs, git_dir, spec) is Some(id) else {
      raise @bitcore.GitError::InvalidObject("bad revision '\{spec}'")
    }
    id
  }

  // A bare positional arg is a revision range, a single revision, or a pathspec.
  fn classify_positional(arg : String) -> Unit raise Error {
    // Range forms: A..B and A...B (bottom A excluded, start B).
    match lm_find_range_sep(arg) {
      Some(pos) => {
        let three = pos + 2 < arg.length() && arg[pos + 2] == '.'
        let left = String::unsafe_substring(arg, start=0, end=pos)
        let right_start = pos + (if three { 3 } else { 2 })
        let right = String::unsafe_substring(
          arg,
          start=right_start,
          end=arg.length(),
        )
        let left_spec = if left.length() == 0 { "HEAD" } else { left }
        let right_spec = if right.length() == 0 { "HEAD" } else { right }
        bottoms.push(resolve_rev(left_spec))
        set_rev(right_spec)
      }
      None =>
        match @bitrepo.rev_parse(rfs, git_dir, arg) {
          Some(_) => set_rev(arg)
          None => add_pathspec(arg)
        }
    }
  }

  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if only_positional {
      add_pathspec(arg)
      i += 1
      continue
    }
    match arg {
      "-r" | "--recursive" => max_depth = -1
      "-t" | "--show-trees" => show_trees = true
      "-z" => nul = true
      "--" => only_positional = true
      _ =>
        if arg.has_prefix("--max-depth=") {
          let v = String::unsafe_substring(arg, start=12, end=arg.length())
          max_depth = @string.parse_int(v) catch {
            _ =>
              raise @bitcore.GitError::InvalidObject(
                "invalid --max-depth value: \{v}",
              )
          }
        } else if arg.has_prefix("--max-count=") {
          let v = String::unsafe_substring(arg, start=12, end=arg.length())
          max_count = @string.parse_int(v) catch { _ => -1 }
        } else if arg.length() > 1 &&
          arg[0] == '-' &&
          lm_is_all_digits(
            String::unsafe_substring(arg, start=1, end=arg.length()),
          ) {
          max_count = @string.parse_int(
            String::unsafe_substring(arg, start=1, end=arg.length()),
          ) catch {
            _ => -1
          }
        } else if arg.has_prefix("--") {
          raise @bitcore.GitError::InvalidObject(
            "unknown last-modified argument: \{arg}",
          )
        } else {
          classify_positional(arg)
        }
    }
    i += 1
  }

  // -- resolve start commit and run the core --------------------------------
  let spec = rev_spec.unwrap_or("HEAD")
  guard @bitrepo.rev_parse(rfs, git_dir, spec) is Some(start_id) else {
    raise @bitcore.GitError::InvalidObject("bad revision '\{spec}'")
  }
  let results = @bitlib.last_modified_compute(
    db, rfs, start_id, spec, max_depth, show_trees, max_count, bottoms, pathspecs,
  )

  // -- emit -----------------------------------------------------------------
  let buf = StringBuilder::new()
  for r in results {
    if r.boundary {
      buf.write_char('^')
    }
    buf.write_string(r.oid.to_hex())
    buf.write_char('\t')
    if nul {
      buf.write_string(r.path)
      buf.write_char('\u{00}')
    } else {
      buf.write_string(c_quote_path(r.path))
      buf.write_char('\n')
    }
  }
  print_str(buf.to_string())
}
