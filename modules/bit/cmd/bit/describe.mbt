///|
async fn handle_describe(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  // Parse options
  let mut use_tags = false // --tags: use lightweight tags too
  let mut always = false // --always: show abbreviated commit if no tag
  let mut long_format = false // --long: always use long format
  let mut abbrev = 7 // --abbrev=N: abbreviation length
  let mut commit_ref = "HEAD"
  let mut dirty_mark = ""
  // --match/--exclude: glob patterns restricting which tags are considered.
  // Both the two-arg (`--match <pat>`) and `--match=<pat>` forms are accepted,
  // and each may be given multiple times (matching git).
  let match_patterns : Array[String] = []
  let exclude_patterns : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--tags" {
      use_tags = true
    } else if arg == "--always" {
      always = true
    } else if arg == "--long" {
      long_format = true
    } else if arg == "--dirty" {
      dirty_mark = "-dirty"
    } else if arg.has_prefix("--abbrev=") {
      abbrev = parse_int(
        String::unsafe_substring(arg, start=9, end=arg.length()),
      )
    } else if arg.has_prefix("--dirty=") {
      dirty_mark = String::unsafe_substring(arg, start=8, end=arg.length())
    } else if arg == "--match" {
      i = i + 1
      if i < args.length() {
        match_patterns.push(args[i])
      }
    } else if arg.has_prefix("--match=") {
      match_patterns.push(
        String::unsafe_substring(arg, start=8, end=arg.length()),
      )
    } else if arg == "--exclude" {
      i = i + 1
      if i < args.length() {
        exclude_patterns.push(args[i])
      }
    } else if arg.has_prefix("--exclude=") {
      exclude_patterns.push(
        String::unsafe_substring(arg, start=10, end=arg.length()),
      )
    } else if !arg.has_prefix("-") {
      commit_ref = arg
    }
    i = i + 1
  }
  // Resolve target commit
  let target_id = @bitrepo.rev_parse(rfs, git_dir, commit_ref)
  guard target_id is Some(tid0) else {
    raise @bitcore.GitError::InvalidObject("unknown revision: \{commit_ref}")
  }
  // Peel annotated tag objects down to the commit they point at, matching
  // `git describe` (e.g. `git describe <tag-object-sha>` describes the commit).
  let tid = describe_peel_to_commit(rfs, git_dir, tid0)
  // Get all tags, then apply --match/--exclude filtering on the tag name.
  let tags = filter_tags(
    get_all_tags(rfs, git_dir, use_tags),
    match_patterns,
    exclude_patterns,
  )
  if tags.length() == 0 && !always {
    @stdio.stderr.write("fatal: No names found, cannot describe anything.")
    @sys.exit(128)
  }
  // Find closest tag using BFS
  let result = find_closest_tag(rfs, git_dir, tid, tags)
  match result {
    Some((tag_name, distance, tag_commit)) => {
      let output = if distance == 0 && !long_format {
        tag_name + dirty_mark
      } else {
        let short_sha = String::unsafe_substring(
          tid.to_hex(),
          start=0,
          end=abbrev,
        )
        "\{tag_name}-\{distance}-g\{short_sha}\{dirty_mark}"
      }
      ignore(tag_commit)
      print_line(output)
    }
    None =>
      if always {
        let short_sha = String::unsafe_substring(
          tid.to_hex(),
          start=0,
          end=abbrev,
        )
        print_line(short_sha + dirty_mark)
      } else {
        @stdio.stderr.write(
          "fatal: No tags can describe '\{tid.to_hex()}'.\nTry --always, or create a tag.",
        )
        @sys.exit(128)
      }
  }
}

///|
fn get_all_tags(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  include_lightweight : Bool,
) -> Map[String, @bitcore.ObjectId] raise Error {
  let tags : Map[String, @bitcore.ObjectId] = Map([])
  let tags_dir = git_dir + "/refs/tags"
  if !rfs.is_dir(tags_dir) {
    return tags
  }
  let entries = rfs.readdir(tags_dir) catch { _ => return tags }
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  for entry in entries {
    let tag_path = tags_dir + "/" + entry
    if rfs.is_file(tag_path) {
      let ref_hex = rfs.read_file(tag_path) |> decode_bytes |> trim_string
      let ref_id = @bitcore.ObjectId::from_hex(ref_hex)
      // Check if it's an annotated tag (tag object) or lightweight (commit)
      let obj = db.get(rfs, ref_id)
      match obj {
        Some(o) =>
          if o.obj_type == @bitcore.ObjectType::Tag {
            // Annotated tag - dereference to commit
            let tag_data = decode_bytes(o.data)
            let commit_id = parse_tag_object(tag_data)
            match commit_id {
              Some(cid) => tags[entry] = cid
              None => ()
            }
          } else if o.obj_type == @bitcore.ObjectType::Commit &&
            include_lightweight {
            // Lightweight tag
            tags[entry] = ref_id
          }
        None => ()
      }
    }
  }
  tags
}

///|
fn parse_tag_object(data : String) -> @bitcore.ObjectId? raise Error {
  @bitlib.parse_tag_object(data)
}

///|
/// Follow a chain of annotated tag objects to the commit they ultimately point
/// at. Non-tag objects (and unresolvable ids) are returned unchanged.
fn describe_peel_to_commit(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  id : @bitcore.ObjectId,
) -> @bitcore.ObjectId raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let mut cur = id
  for _depth in 0..<10 {
    match db.get(rfs, cur) {
      Some(o) =>
        if o.obj_type == @bitcore.ObjectType::Tag {
          match parse_tag_object(decode_bytes(o.data)) {
            Some(t) => cur = t
            None => break
          }
        } else {
          break
        }
      None => break
    }
  }
  cur
}

///|
/// Whether `name` matches any of the glob `patterns`.
fn matches_any(patterns : Array[String], name : String) -> Bool {
  for pat in patterns {
    if @ignore.match_glob(pat, name) {
      return true
    }
  }
  false
}

///|
/// Restrict candidate tags by `--match`/`--exclude` glob patterns (matched
/// against the tag name). A tag is kept when it matches at least one match
/// pattern (or none were given) and matches no exclude pattern.
fn filter_tags(
  tags : Map[String, @bitcore.ObjectId],
  match_patterns : Array[String],
  exclude_patterns : Array[String],
) -> Map[String, @bitcore.ObjectId] {
  if match_patterns.length() == 0 && exclude_patterns.length() == 0 {
    return tags
  }
  let filtered : Map[String, @bitcore.ObjectId] = Map([])
  for name, cid in tags {
    let included = match_patterns.length() == 0 ||
      matches_any(match_patterns, name)
    if included && !matches_any(exclude_patterns, name) {
      filtered[name] = cid
    }
  }
  filtered
}

///|
fn find_closest_tag(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  target : @bitcore.ObjectId,
  tags : Map[String, @bitcore.ObjectId],
) -> (String, Int, @bitcore.ObjectId)? raise Error {
  // BFS from target to find closest tag
  // Queue entries: (commit_id, distance)
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let visited : Map[String, Bool] = Map([])
  let queue : Array[(@bitcore.ObjectId, Int)] = [(target, 0)]
  while queue.length() > 0 {
    // Dequeue from front (FIFO for BFS)
    let (current, distance) = queue[0]
    let new_queue : Array[(@bitcore.ObjectId, Int)] = []
    for i in 1..<queue.length() {
      new_queue.push(queue[i])
    }
    // Clear and refill queue
    while queue.length() > 0 {
      ignore(queue.pop())
    }
    for item in new_queue {
      queue.push(item)
    }
    let hex = current.to_hex()
    if visited.get(hex).unwrap_or(false) {
      continue
    }
    visited[hex] = true
    // Check if this commit has a tag
    for tag_name, tag_commit in tags {
      if tag_commit.to_hex() == hex {
        return Some((tag_name, distance, tag_commit))
      }
    }
    // Add parents to queue
    let obj = db.get(rfs, current)
    match obj {
      Some(o) => {
        let info = @bitcore.parse_commit(o.data)
        for p in info.parents {
          if !visited.get(p.to_hex()).unwrap_or(false) {
            queue.push((p, distance + 1))
          }
        }
      }
      None => ()
    }
  }
  None
}

///|
fn parse_int(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
/// Handle git format-patch command
