///|
struct FormatPatchOptions {
  output_dir : String?
  output_file : String?
  start_number : Int
  numbered : Bool
  stdout_mode : Bool
  cover_letter : Bool
  revisions : Array[String]
  grep_patterns : Array[String]
  grep_pattern_type_override : GrepPatternType?
  grep_ignore_case : Bool
  signature : String?
  signature_file : String?
  no_signature : Bool
}

///|
fn is_format_patch_count_arg(arg : String) -> Bool {
  if arg.length() <= 1 || arg[0] != '-' {
    return false
  }
  for c in String::unsafe_substring(arg, start=1, end=arg.length()) {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
fn parse_format_patch_options(args : Array[String]) -> FormatPatchOptions {
  let mut output_dir : String? = None
  let mut output_file : String? = None
  let mut start_number = 1
  let mut numbered = false
  let mut stdout_mode = false
  let mut cover_letter = false
  let revisions : Array[String] = []
  let grep_patterns : Array[String] = []
  let mut grep_pattern_type_override : GrepPatternType? = None
  let mut grep_ignore_case = false
  let mut signature : String? = None
  let mut signature_file : String? = None
  let mut no_signature = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-o" | "--output-directory" if i + 1 < args.length() => {
        output_dir = Some(args[i + 1])
        i += 2
      }
      "--output" if i + 1 < args.length() => {
        output_file = Some(args[i + 1])
        i += 2
      }
      "--start-number" if i + 1 < args.length() => {
        start_number = parse_int(args[i + 1])
        i += 2
      }
      "--signature" if i + 1 < args.length() => {
        signature = Some(args[i + 1])
        i += 2
      }
      "--signature-file" if i + 1 < args.length() => {
        signature_file = Some(args[i + 1])
        i += 2
      }
      "-n" | "--numbered" => {
        numbered = true
        i += 1
      }
      "--stdout" => {
        stdout_mode = true
        i += 1
      }
      "--cover-letter" => {
        cover_letter = true
        i += 1
      }
      "--no-signature" => {
        no_signature = true
        i += 1
      }
      "--grep" if i + 1 < args.length() => {
        grep_patterns.push(args[i + 1])
        i += 2
      }
      _ if arg.has_prefix("--grep=") => {
        grep_patterns.push(
          String::unsafe_substring(arg, start=7, end=arg.length()),
        )
        i += 1
      }
      "-i" | "--regexp-ignore-case" => {
        grep_ignore_case = true
        i += 1
      }
      "-F" | "--fixed-strings" => {
        grep_pattern_type_override = Some(GrepPatternType::Fixed)
        i += 1
      }
      "-E" | "--extended-regexp" => {
        grep_pattern_type_override = Some(GrepPatternType::Extended)
        i += 1
      }
      "-P" | "--perl-regexp" => {
        grep_pattern_type_override = Some(GrepPatternType::Perl)
        i += 1
      }
      "--basic-regexp" => {
        grep_pattern_type_override = Some(GrepPatternType::Basic)
        i += 1
      }
      _ if arg.has_prefix("--output-directory=") => {
        output_dir = Some(
          String::unsafe_substring(arg, start=19, end=arg.length()),
        )
        i += 1
      }
      _ if arg.has_prefix("--output=") => {
        output_file = Some(
          String::unsafe_substring(arg, start=9, end=arg.length()),
        )
        i += 1
      }
      _ if arg.has_prefix("--signature=") => {
        signature = Some(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
        i += 1
      }
      _ if arg.has_prefix("--signature-file=") => {
        signature_file = Some(
          String::unsafe_substring(arg, start=17, end=arg.length()),
        )
        i += 1
      }
      _ if arg.has_prefix("-o") => {
        output_dir = Some(
          String::unsafe_substring(arg, start=2, end=arg.length()),
        )
        i += 1
      }
      _ if is_format_patch_count_arg(arg) || !arg.has_prefix("-") => {
        revisions.push(arg)
        i += 1
      }
      _ => i += 1
    }
  }
  {
    output_dir,
    output_file,
    start_number,
    numbered,
    stdout_mode,
    cover_letter,
    revisions,
    grep_patterns,
    grep_pattern_type_override,
    grep_ignore_case,
    signature,
    signature_file,
    no_signature,
  }
}

///|
fn read_format_patch_signature_file(path : String) -> String? {
  Some(@fs.read_file_to_string(path)) catch {
    _ => None
  }
}

///|
fn format_patch_default_signature() -> String {
  match bit_version_tag.find(" (bit ") {
    Some(idx) => String::unsafe_substring(bit_version_tag, start=0, end=idx)
    None => bit_version_tag
  }
}

///|
fn resolve_format_patch_signature(
  git_dir : String,
  opts : FormatPatchOptions,
) -> String? {
  if opts.no_signature {
    return None
  }
  match opts.signature {
    Some(sig) => return if sig.length() == 0 { None } else { Some(sig) }
    None => ()
  }
  match opts.signature_file {
    Some(path) => return read_format_patch_signature_file(path)
    None => ()
  }
  match bit_config_get(git_dir, "format", "signature") {
    Some(sig) => return if sig.length() == 0 { None } else { Some(sig) }
    None => ()
  }
  match bit_config_get(git_dir, "format", "signaturefile") {
    Some(path) => return read_format_patch_signature_file(path)
    None => ()
  }
  Some(format_patch_default_signature())
}

///|
fn format_patch_signature_suffix(signature : String?) -> String {
  match signature {
    None => ""
    Some(sig) =>
      if sig.length() == 0 {
        ""
      } else if sig[sig.length() - 1] == '\n' {
        "-- \n" + sig + "\n"
      } else {
        "-- \n" + sig + "\n\n"
      }
  }
}

///|
fn format_patch_concat(parts : Array[String]) -> String {
  let sb = StringBuilder::new()
  for part in parts {
    sb.write_string(part)
  }
  sb.to_string()
}

///|
async fn handle_format_patch(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let fs = OsFs::new()
  let wfs : &@bitcore.FileSystem = fs
  let rfs : &@bitcore.RepoFileSystem = fs
  let opts = parse_format_patch_options(args)
  if opts.stdout_mode &&
    (opts.output_dir is Some(_) || opts.output_file is Some(_)) {
    @stdio.stderr.write("fatal: multiple output destinations specified\n")
    @sys.exit(128)
  }
  if opts.output_dir is Some(_) && opts.output_file is Some(_) {
    @stdio.stderr.write("fatal: multiple output destinations specified\n")
    @sys.exit(128)
  }
  let (base_commit, commits) = parse_format_patch_revisions(
    rfs,
    git_dir,
    opts.revisions,
  )
  if commits.length() == 0 {
    @stdio.stderr.write("fatal: no commits specified")
    @sys.exit(128)
  }
  let grep_pattern_type = resolve_grep_pattern_type(
    rfs,
    git_dir,
    opts.grep_pattern_type_override,
  )
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let commits = filter_format_patch_commits_by_grep(
    db,
    rfs,
    commits,
    opts.grep_patterns,
    grep_pattern_type,
    opts.grep_ignore_case,
  )
  if commits.length() == 0 {
    return
  }
  let signature = resolve_format_patch_signature(git_dir, opts)
  let output_dir = match opts.output_dir {
    Some(dir) => dir
    None =>
      if opts.stdout_mode || opts.output_file is Some(_) {
        "."
      } else {
        bit_config_get(git_dir, "format", "outputDirectory").unwrap_or(".")
      }
  }
  if !opts.stdout_mode && opts.output_file is None && !rfs.is_dir(output_dir) {
    wfs.mkdir_p(output_dir)
  }
  let total = commits.length()
  let stdout_parts : Array[String] = []
  if opts.cover_letter {
    let cover_content = generate_cover_letter(commits.length(), signature)
    if opts.stdout_mode || opts.output_file is Some(_) {
      stdout_parts.push(cover_content)
    } else {
      let cover_path = output_dir + "/0000-cover-letter.patch"
      wfs.write_string(cover_path, cover_content)
      print_line(cover_path)
    }
  }
  for idx in 0..<commits.length() {
    let commit_id = commits[idx]
    let patch_num = opts.start_number + idx
    let patch = generate_patch(
      db,
      rfs,
      git_dir,
      commit_id,
      base_commit,
      patch_num,
      total,
      opts.numbered,
      signature,
    )
    if opts.stdout_mode || opts.output_file is Some(_) {
      stdout_parts.push(patch)
    } else {
      let filename = format_patch_filename(
        db,
        rfs,
        commit_id,
        patch_num,
        total,
        opts.numbered,
      )
      let patch_path = output_dir + "/" + filename
      wfs.write_string(patch_path, patch)
      print_line(patch_path)
    }
  }
  if opts.stdout_mode || opts.output_file is Some(_) {
    let output = format_patch_concat(stdout_parts)
    match opts.output_file {
      Some(path) => wfs.write_string(path, output)
      None => print_str(output)
    }
  }
  ignore(base_commit)
}

///|
fn parse_format_patch_revisions(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  revisions : Array[String],
) -> (@bitcore.ObjectId?, Array[@bitcore.ObjectId]) raise Error {
  if revisions.length() == 0 {
    // Default: HEAD~1..HEAD (last commit)
    let head = @bitrepo.rev_parse(rfs, git_dir, "HEAD")
    guard head is Some(h) else { return (None, []) }
    return (None, [h])
  }
  let mut count_arg : String? = None
  let mut range_arg : String? = None
  let mut single_arg : String? = None
  for revision in revisions {
    if revision.find("..") is Some(_) {
      range_arg = Some(revision)
    } else if is_format_patch_count_arg(revision) {
      count_arg = Some(revision)
    } else {
      single_arg = Some(revision)
    }
  }
  match range_arg {
    Some(rev) =>
      match rev.find("..") {
        Some(idx) => {
          let base_ref = String::unsafe_substring(rev, start=0, end=idx)
          let end_ref = String::unsafe_substring(
            rev,
            start=idx + 2,
            end=rev.length(),
          )
          let base_id = @bitrepo.rev_parse(rfs, git_dir, base_ref)
          let end_id = @bitrepo.rev_parse(
            rfs,
            git_dir,
            if end_ref.length() == 0 {
              "HEAD"
            } else {
              end_ref
            },
          )
          guard base_id is Some(bid) && end_id is Some(eid) else {
            return (None, [])
          }
          let commits = collect_commits_in_range(rfs, git_dir, bid, eid)
          return (Some(bid), commits)
        }
        None => ()
      }
    None => ()
  }
  match count_arg {
    Some(rev) => {
      let n = parse_int(
        String::unsafe_substring(rev, start=1, end=rev.length()),
      )
      let end_ref = single_arg.unwrap_or("HEAD")
      let commits = collect_last_n_commits_from(rfs, git_dir, n, end_ref)
      return (None, commits)
    }
    None => ()
  }
  let rev = single_arg.unwrap_or(revisions[0])
  // Check for range notation
  match rev.find("..") {
    Some(idx) => {
      let base_ref = String::unsafe_substring(rev, start=0, end=idx)
      let end_ref = String::unsafe_substring(
        rev,
        start=idx + 2,
        end=rev.length(),
      )
      let base_id = @bitrepo.rev_parse(rfs, git_dir, base_ref)
      let end_id = @bitrepo.rev_parse(
        rfs,
        git_dir,
        if end_ref.length() == 0 {
          "HEAD"
        } else {
          end_ref
        },
      )
      guard base_id is Some(bid) && end_id is Some(eid) else {
        return (None, [])
      }
      // Collect commits from end to base
      let commits = collect_commits_in_range(rfs, git_dir, bid, eid)
      (Some(bid), commits)
    }
    None =>
      // Check for -N notation (last N commits)
      if rev.has_prefix("-") {
        let n = parse_int(
          String::unsafe_substring(rev, start=1, end=rev.length()),
        )
        let commits = collect_last_n_commits_from(rfs, git_dir, n, "HEAD")
        (None, commits)
      } else {
        // Single commit
        let id = @bitrepo.rev_parse(rfs, git_dir, rev)
        guard id is Some(cid) else { return (None, []) }
        (None, [cid])
      }
  }
}

///|
fn collect_commits_in_range(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  base : @bitcore.ObjectId,
  end : @bitcore.ObjectId,
) -> Array[@bitcore.ObjectId] raise Error {
  let excluded : Map[String, Bool] = {}
  let base_entries = log_walk_commits(
    rfs,
    git_dir,
    [base],
    {},
    2147483647,
    0L,
    9223372036854775807L,
    false,
  )
  for entry in base_entries {
    excluded[entry.id.to_hex()] = true
  }
  let entries = log_walk_commits(
    rfs,
    git_dir,
    [end],
    excluded,
    2147483647,
    0L,
    9223372036854775807L,
    false,
  )
  let result : Array[@bitcore.ObjectId] = []
  for entry in entries {
    result.push(entry.id)
  }
  result.rev_in_place()
  result
}

///|
fn collect_last_n_commits_from(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  n : Int,
  end_ref : String,
) -> Array[@bitcore.ObjectId] raise Error {
  let db = @bitlib.ObjectDb::load(rfs, git_dir)
  let head = @bitrepo.rev_parse(rfs, git_dir, end_ref)
  guard head is Some(h) else { return [] }
  let result : Array[@bitcore.ObjectId] = []
  let mut current = h
  for _ in 0..<n {
    result.push(current)
    let obj = db.get(rfs, current)
    guard obj is Some(o) else { break }
    let info = @bitcore.parse_commit(o.data)
    if info.parents.length() == 0 {
      break
    }
    current = info.parents[0]
  }
  result.rev_in_place()
  result
}

///|
fn filter_format_patch_commits_by_grep(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commits : Array[@bitcore.ObjectId],
  grep_patterns : Array[String],
  grep_pattern_type : GrepPatternType,
  grep_ignore_case : Bool,
) -> Array[@bitcore.ObjectId] raise Error {
  if grep_patterns.length() == 0 {
    return commits
  }
  let filtered : Array[@bitcore.ObjectId] = []
  for commit_id in commits {
    let obj = db.get(rfs, commit_id)
    guard obj is Some(o) else { continue }
    if o.obj_type != @bitcore.ObjectType::Commit {
      continue
    }
    let commit_message = extract_commit_message_from_raw(o.data)
    if grep_patterns_match_message(
        commit_message, grep_patterns, grep_pattern_type, grep_ignore_case,
      ) {
      filtered.push(commit_id)
    }
  }
  filtered
}

///|
fn generate_cover_letter(num_patches : Int, signature : String?) -> String {
  let sb = StringBuilder::new()
  sb.write_string(
    "From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001\n",
  )
  sb.write_string("Subject: [PATCH 0/")
  sb.write_string(num_patches.to_string())
  sb.write_string("] *** SUBJECT HERE ***\n\n")
  sb.write_string("*** BLURB HERE ***\n\n")
  sb.write_string(format_patch_signature_suffix(signature))
  sb.to_string()
}

///|
fn generate_patch(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  commit_id : @bitcore.ObjectId,
  _base : @bitcore.ObjectId?,
  patch_num : Int,
  total : Int,
  numbered : Bool,
  signature : String?,
) -> String raise Error {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else {
    raise @bitcore.GitError::InvalidObject("commit not found")
  }
  let commit_text = decode_bytes(o.data)
  let info = @bitcore.parse_commit(o.data)
  // Extract commit details
  let author_line = extract_author_line(commit_text)
  let message = extract_commit_message(o.data)
  let subject = get_first_line(message)
  let body = get_rest_lines(message)
  // Build patch header
  let sb = StringBuilder::new()
  sb.write_string("From ")
  sb.write_string(commit_id.to_hex())
  sb.write_string(" Mon Sep 17 00:00:00 2001\n")
  sb.write_string("From: ")
  sb.write_string(author_line)
  sb.write_string("\n")
  // Date from author line
  let (_, author_time, author_tz) = parse_author_info(author_line)
  sb.write_string("Date: ")
  sb.write_string(format_email_date(author_time, author_tz))
  sb.write_string("\n")
  // Subject
  sb.write_string("Subject: ")
  if numbered || total > 1 {
    sb.write_string("[PATCH ")
    sb.write_string(patch_num.to_string())
    sb.write_string("/")
    sb.write_string(total.to_string())
    sb.write_string("] ")
  }
  sb.write_string(subject)
  sb.write_string("\n\n")
  // Body
  if body.length() > 0 {
    sb.write_string(body)
    sb.write_string("\n")
  }
  sb.write_string("---\n")
  // Generate diff
  let parent_id = if info.parents.length() > 0 {
    Some(info.parents[0])
  } else {
    None
  }
  let diff = generate_commit_diff(db, rfs, git_dir, commit_id, parent_id)
  sb.write_string(diff)
  sb.write_string("\n")
  sb.write_string(format_patch_signature_suffix(signature))
  sb.to_string()
}

///|
fn format_patch_filename(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  commit_id : @bitcore.ObjectId,
  patch_num : Int,
  _total : Int,
  _numbered : Bool,
) -> String raise Error {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else {
    return pad_left_zero(patch_num.to_string(), 4) + "-patch.patch"
  }
  let message = extract_commit_message(o.data)
  let subject = get_first_line(message)
  // Sanitize subject for filename
  let sanitized = sanitize_filename(subject)
  let num_str = pad_left_zero(patch_num.to_string(), 4)
  num_str + "-" + sanitized + ".patch"
}

///|
fn sanitize_filename(s : String) -> String {
  let sb = StringBuilder::new()
  let mut last_was_dash = false
  for c in s {
    if (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') {
      sb.write_char(c)
      last_was_dash = false
    } else if !last_was_dash {
      sb.write_char('-')
      last_was_dash = true
    }
  }
  let result = sb.to_string()
  // Trim trailing dash
  if result.length() > 0 && result[result.length() - 1] == '-' {
    String::unsafe_substring(result, start=0, end=result.length() - 1)
  } else {
    result
  }
}

///|
fn get_first_line(s : String) -> String {
  match s.find("\n") {
    Some(idx) => String::unsafe_substring(s, start=0, end=idx)
    None => s
  }
}

///|
fn get_rest_lines(s : String) -> String {
  match s.find("\n") {
    Some(idx) =>
      trim_string(String::unsafe_substring(s, start=idx + 1, end=s.length()))
    None => ""
  }
}

///|
fn format_email_date(ts : Int64, tz : String) -> String {
  let secs = ts.to_int()
  let days = secs / 86400
  let time_of_day = secs % 86400
  let hours = time_of_day / 3600
  let minutes = time_of_day % 3600 / 60
  let seconds = time_of_day % 60
  let (year, month, day) = days_to_date(days)
  let weekday = (days + 4) % 7 // Jan 1, 1970 was Thursday (4)
  let weekday_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let wd = weekday_names[weekday]
  let mn = month_names[month - 1]
  "\{wd}, \{day} \{mn} \{year} \{pad_left_zero(hours.to_string(), 2)}:\{pad_left_zero(minutes.to_string(), 2)}:\{pad_left_zero(seconds.to_string(), 2)} \{tz}"
}

///|
fn generate_commit_diff(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  commit_id : @bitcore.ObjectId,
  parent_id : @bitcore.ObjectId?,
) -> String raise Error {
  let obj = db.get(rfs, commit_id)
  guard obj is Some(o) else { return "" }
  let info = @bitcore.parse_commit(o.data)
  let tree = info.tree
  let parent_tree = match parent_id {
    Some(pid) => {
      let pobj = db.get(rfs, pid)
      match pobj {
        Some(po) => {
          let pinfo = @bitcore.parse_commit(po.data)
          Some(pinfo.tree)
        }
        None => None
      }
    }
    None => None
  }
  let diff_files = @bitdiff.diff_trees(rfs, git_dir, parent_tree, tree, db~)
  @bitdiff.diff_text(diff_files).join("\n")
}

///|
fn get_tree_entries(
  db : @bitlib.ObjectDb,
  rfs : &@bitcore.RepoFileSystem,
  tree_id : @bitcore.ObjectId,
) -> Array[@bitcore.TreeEntry] raise Error {
  let obj = db.get(rfs, tree_id)
  guard obj is Some(o) else { return [] }
  @bitcore.parse_tree(o.data)
}

///|
/// Handle git shortlog command
