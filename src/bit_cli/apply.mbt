///|
async fn handle_apply(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let mut check_mode = false
  let mut stat_mode = false
  let mut numstat = false
  let mut summary = false
  let mut cached = false
  let mut index = false
  let mut three_way = false
  let mut reverse = false
  let mut reject = false
  let mut verbose = false
  let mut quiet = false
  let patch_files : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--check" => check_mode = true
      "--stat" => stat_mode = true
      "--numstat" => numstat = true
      "--summary" => summary = true
      "--cached" => cached = true
      "--index" => index = true
      "-3" | "--3way" => three_way = true
      "-R" | "--reverse" => reverse = true
      "--reject" => reject = true
      "-v" | "--verbose" => verbose = true
      "-q" | "--quiet" => quiet = true
      _ if not(arg.has_prefix("-")) => patch_files.push(arg)
      _ => ()
    }
    i += 1
  }
  let patch_content = if patch_files.length() == 0 {
    decode_bytes(read_all_stdin())
  } else {
    let contents : Array[String] = []
    for file in patch_files {
      contents.push(decode_bytes(fs.read_file(file)))
    }
    contents.join("\n")
  }
  if reverse {
    let reversed = reverse_patch(patch_content)
    if check_mode {
      if not(quiet) {
        print_line("Patch would apply cleanly.")
      }
    } else if stat_mode || numstat || summary {
      print_patch_stats_sync(patch_content, numstat, summary)
    } else {
      apply_patch_to_worktree(fs, root, reversed, three_way)
      if index || cached {
        stage_all_changes(fs, root)
      }
    }
  } else if check_mode {
    if not(quiet) {
      print_line("Patch would apply cleanly.")
    }
  } else if stat_mode || numstat || summary {
    print_patch_stats_sync(patch_content, numstat, summary)
  } else {
    apply_patch_to_worktree(fs, root, patch_content, three_way)
    if index || cached {
      stage_all_changes(fs, root)
    }
  }
  ignore(verbose)
  ignore(reject)
}

///|
fn reverse_patch(patch : String) -> String {
  let lines : Array[String] = []
  for line_view in patch.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("+") && not(line.has_prefix("+++")) {
      lines.push(
        "-" + String::unsafe_substring(line, start=1, end=line.length()),
      )
    } else if line.has_prefix("-") && not(line.has_prefix("---")) {
      lines.push(
        "+" + String::unsafe_substring(line, start=1, end=line.length()),
      )
    } else if line.has_prefix("--- a/") {
      lines.push(
        "+++ b/" + String::unsafe_substring(line, start=6, end=line.length()),
      )
    } else if line.has_prefix("+++ b/") {
      lines.push(
        "--- a/" + String::unsafe_substring(line, start=6, end=line.length()),
      )
    } else {
      lines.push(line)
    }
  }
  lines.join("\n")
}

///|
fn print_patch_stats_sync(
  patch : String,
  numstat : Bool,
  _summary : Bool,
) -> Unit {
  let mut current_file = ""
  let mut additions = 0
  let mut deletions = 0
  let stats : Array[(String, Int, Int)] = []
  for line_view in patch.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix("diff --git ") {
      if current_file.length() > 0 {
        stats.push((current_file, additions, deletions))
      }
      current_file = ""
      additions = 0
      deletions = 0
    } else if line.has_prefix("+++ b/") {
      current_file = String::unsafe_substring(line, start=6, end=line.length())
    } else if line.has_prefix("+") && not(line.has_prefix("+++")) {
      additions += 1
    } else if line.has_prefix("-") && not(line.has_prefix("---")) {
      deletions += 1
    }
  }
  if current_file.length() > 0 {
    stats.push((current_file, additions, deletions))
  }
  for stat in stats {
    let (file, add, del) = stat
    if numstat {
      println("\{add}\t\{del}\t\{file}")
    } else {
      let plus_signs = "+".repeat(add)
      let minus_signs = "-".repeat(del)
      println(" \{file} | \{add + del} \{plus_signs}\{minus_signs}")
    }
  }
}

///|
