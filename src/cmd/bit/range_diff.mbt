///|
async fn handle_range_diff(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let ranges : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--creation-factor" if i + 1 < args.length() => {
        i += 2
        continue
      }
      "--no-dual-color" | "--dual-color" | "--no-color" => ()
      _ if arg.has_prefix("--creation-factor=") => ()
      _ if not(arg.has_prefix("-")) => ranges.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("range-diff", arg)
      _ => ()
    }
    i += 1
  }
  // Parse ranges - can be:
  // 1. <range1> <range2> - two revision ranges
  // 2. <rev1>...<rev2> - symmetric difference style
  // 3. <base> <rev1> <rev2> - three-argument form
  let (range1_start, range1_end, range2_start, range2_end) = if ranges.length() ==
    3 {
    // Three-argument form: base rev1 rev2
    (ranges[0], ranges[1], ranges[0], ranges[2])
  } else if ranges.length() == 2 {
    // Two revision ranges
    let (s1, e1) = plumb_parse_range(ranges[0])
    let (s2, e2) = plumb_parse_range(ranges[1])
    (s1, e1, s2, e2)
  } else if ranges.length() == 1 && ranges[0].contains("...") {
    // Symmetric difference: A...B means A..B compared to B..A
    match ranges[0].find("...") {
      Some(idx) => {
        let a = ranges[0][:idx].to_string()
        let b = ranges[0][idx + 3:].to_string()
        (a, b, b, a)
      }
      None => {
        eprint_line("fatal: invalid range")
        @sys.exit(128)
        return
      }
    }
  } else {
    eprint_line("usage: git range-diff [<options>] <range1> <range2>")
    eprint_line("       git range-diff [<options>] <rev1>...<rev2>")
    eprint_line("       git range-diff [<options>] <base> <rev1> <rev2>")
    @sys.exit(1)
    return
  }
  // Resolve revisions
  let r1_start = @bitrepo.rev_parse(fs, git_dir, range1_start)
  let r1_end = @bitrepo.rev_parse(fs, git_dir, range1_end)
  let r2_start = @bitrepo.rev_parse(fs, git_dir, range2_start)
  let r2_end = @bitrepo.rev_parse(fs, git_dir, range2_end)
  guard r1_start is Some(r1s) &&
    r1_end is Some(r1e) &&
    r2_start is Some(r2s) &&
    r2_end is Some(r2e) else {
    eprint_line("fatal: could not resolve revisions")
    @sys.exit(128)
    return
  }
  // Collect commits in each range
  let commits1 = plumb_collect_range_commits(fs, git_dir, r1s, r1e)
  let commits2 = plumb_collect_range_commits(fs, git_dir, r2s, r2e)
  // Output range-diff
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let mut idx1 = 1
  let mut idx2 = 1
  // Simple matching by commit message
  let matched : Map[String, Int] = {}
  for c in commits2 {
    let msg = plumb_get_commit_subject(db, fs, c)
    matched[msg] = idx2
    idx2 += 1
  }
  idx2 = 1
  for c1 in commits1 {
    let msg1 = plumb_get_commit_subject(db, fs, c1)
    match matched.get(msg1) {
      Some(m_idx) =>
        // Matched
        print_line(
          idx1.to_string() +
          ":  " +
          c1.to_hex()[:7].to_string() +
          " = " +
          m_idx.to_string() +
          ":  " +
          msg1,
        )
      None =>
        // Only in range1
        print_line(
          idx1.to_string() +
          ":  " +
          c1.to_hex()[:7].to_string() +
          " < -:  ------- " +
          msg1,
        )
    }
    idx1 += 1
  }
  // Show commits only in range2
  for c2 in commits2 {
    let msg2 = plumb_get_commit_subject(db, fs, c2)
    let mut found = false
    for c1 in commits1 {
      if plumb_get_commit_subject(db, fs, c1) == msg2 {
        found = true
        break
      }
    }
    if not(found) {
      print_line(
        "-:  ------- > " +
        idx2.to_string() +
        ":  " +
        c2.to_hex()[:7].to_string() +
        " " +
        msg2,
      )
    }
    idx2 += 1
  }
}

///|
fn plumb_parse_range(range : String) -> (String, String) {
  match range.find("..") {
    Some(idx) =>
      (
        String::unsafe_substring(range, start=0, end=idx),
        String::unsafe_substring(range, start=idx + 2, end=range.length()),
      )
    None => ("", range)
  }
}

///|
fn plumb_collect_range_commits(
  fs : OsFs,
  git_dir : String,
  start : @bitcore.ObjectId,
  end : @bitcore.ObjectId,
) -> Array[@bitcore.ObjectId] {
  let db = @bitlib.ObjectDb::load(fs, git_dir) catch { _ => return [] }
  let result : Array[@bitcore.ObjectId] = []
  let start_hex = start.to_hex()
  let mut current : @bitcore.ObjectId? = Some(end)
  while current is Some(id) {
    if id.to_hex() == start_hex {
      break
    }
    result.push(id)
    let obj = db.get(fs, id) catch { _ => break }
    match obj {
      Some(o) if o.obj_type == @bitcore.ObjectType::Commit => {
        let info = @bitcore.parse_commit(o.data) catch { _ => break }
        current = if info.parents.length() > 0 {
          Some(info.parents[0])
        } else {
          None
        }
      }
      _ => current = None
    }
  }
  result.rev_in_place()
  result
}

///|
fn plumb_get_commit_subject(
  db : @bitlib.ObjectDb,
  fs : OsFs,
  id : @bitcore.ObjectId,
) -> String {
  let obj = db.get(fs, id) catch { _ => return "" }
  match obj {
    Some(o) if o.obj_type == @bitcore.ObjectType::Commit =>
      plumb_get_first_line_of_commit(o.data)
    _ => ""
  }
}

///|
