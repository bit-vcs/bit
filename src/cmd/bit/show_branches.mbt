///|
async fn handle_show_branches(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  // Parse arguments
  let mut show_all = false
  let mut max_count = 10
  let mut show_remotes = false
  let specific_branches : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-a" | "--all" => show_all = true
      "-r" | "--remotes" => show_remotes = true
      "--more" if i + 1 < args.length() => {
        max_count = @strconv.parse_int(args[i + 1]) catch {
          err if @async.is_cancellation_error(err) => raise err
          _ => 10
        }
        i += 2
        continue
      }
      _ if arg.has_prefix("--more=") => {
        let val = String::unsafe_substring(arg, start=7, end=arg.length())
        max_count = @strconv.parse_int(val) catch {
          err if @async.is_cancellation_error(err) => raise err
          _ => 10
        }
      }
      _ if not(arg.has_prefix("-")) => specific_branches.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("show-branch", arg)
      _ => ()
    }
    i += 1
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Get branches to show
  let (head_ref, all_branches) = @bitlib.list_branches(fs, git_dir)
  let branches_to_show : Array[@bitlib.BranchInfo] = if specific_branches.length() >
    0 {
    all_branches.filter(b => specific_branches.contains(b.name))
  } else {
    all_branches
  }
  if branches_to_show.length() == 0 {
    return
  }
  // Print branch headers
  let branch_chars = "!*+-o=#@%&"
  for idx, branch in branches_to_show {
    let marker = if idx < branch_chars.length() {
      branch_chars[idx].to_string()
    } else {
      "!"
    }
    let current_marker = if branch.current { "*" } else { " " }
    // Get commit message
    let msg = show_branch_get_subject(db, fs, branch.id)
    print_line("\{current_marker} [\{branch.name}] \{msg}")
    ignore(marker)
  }
  print_line("---")
  // Print commits with branch indicators
  let displayed : Map[String, Bool] = {}
  for branch_idx, branch in branches_to_show {
    let commits = show_branch_collect_commits(db, fs, branch.id, max_count, {})
    for commit_pair in commits {
      let (commit_id, msg) = commit_pair
      let hex = commit_id.to_hex()
      if displayed.contains(hex) {
        continue
      }
      displayed[hex] = true
      // Build indicator line
      let indicators = StringBuilder::new()
      for i = 0; i < branches_to_show.length(); i = i + 1 {
        if i == branch_idx {
          let ch = if i < branch_chars.length() {
            branch_chars[i].to_string()
          } else {
            "+"
          }
          indicators.write_string(ch)
        } else {
          // Check if this commit is reachable from branch i
          let reachable = show_branch_is_reachable(
            db,
            fs,
            commit_id,
            branches_to_show[i].id,
            max_count * 2,
          )
          if reachable {
            let ch = if i < branch_chars.length() {
              branch_chars[i].to_string()
            } else {
              "+"
            }
            indicators.write_string(ch)
          } else {
            indicators.write_string(" ")
          }
        }
      }
      let short_id = String::unsafe_substring(hex, start=0, end=7)
      print_line("\{indicators.to_string()} [\{short_id}] \{msg}")
    }
  }
  ignore(show_all)
  ignore(show_remotes)
  ignore(head_ref)
}

///|
fn show_branch_get_subject(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
) -> String {
  let obj = db.get(fs, commit_id) catch { _ => return "???" }
  match obj {
    Some(o) => {
      let msg = extract_commit_message(o.data)
      get_first_line(msg)
    }
    None => "???"
  }
}

///|
fn show_branch_collect_commits(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  start : @bitcore.ObjectId,
  max_count : Int,
  skip : Map[String, Bool],
) -> Array[(@bitcore.ObjectId, String)] {
  let result : Array[(@bitcore.ObjectId, String)] = []
  let mut current = start
  let mut count = 0
  while count < max_count {
    let hex = current.to_hex()
    if skip.contains(hex) {
      break
    }
    let obj = db.get(fs, current) catch { _ => break }
    match obj {
      None => break
      Some(o) => {
        let info = @bitcore.parse_commit(o.data) catch { _ => break }
        let msg = extract_commit_message(o.data)
        let subject = get_first_line(msg)
        result.push((current, subject))
        if info.parents.length() == 0 {
          break
        }
        current = info.parents[0]
        count += 1
      }
    }
  }
  result
}

///|
fn show_branch_is_reachable(
  db : @bitlib.ObjectDb,
  fs : &@bitcore.RepoFileSystem,
  target : @bitcore.ObjectId,
  from : @bitcore.ObjectId,
  max_depth : Int,
) -> Bool {
  let target_hex = target.to_hex()
  let mut current = from
  let mut depth = 0
  while depth < max_depth {
    if current.to_hex() == target_hex {
      return true
    }
    let obj = db.get(fs, current) catch { _ => return false }
    match obj {
      None => return false
      Some(o) => {
        let info = @bitcore.parse_commit(o.data) catch { _ => return false }
        if info.parents.length() == 0 {
          return false
        }
        current = info.parents[0]
        depth += 1
      }
    }
  }
  false
}

///|
/// Handle rebase for subdir-clone repositories
