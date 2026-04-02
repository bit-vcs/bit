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
      "--recount" => () // no-op, bit always counts from actual lines
      _ if !arg.has_prefix("-") => patch_files.push(arg)
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
  // Check for corrupt hunk headers (overflow)
  check_corrupt_hunk_headers(patch_content)
  if reverse {
    let reversed = @apply.reverse_patch(patch_content)
    if check_mode {
      if !quiet {
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
    if !quiet {
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
fn print_patch_stats_sync(
  patch : String,
  numstat : Bool,
  summary : Bool,
) -> Unit {
  let patches = @apply.parse_patches(patch)
  if numstat {
    for p in patches {
      println("\{p.additions}\t\{p.deletions}\t\{p.display_name}")
    }
    return
  }
  // Compute max_len and max_change (matching git apply.c show_stats/stat_patch_list)
  let mut max_len = 0
  let mut max_change = 0
  for p in patches {
    if p.display_name.length() > max_len {
      max_len = p.display_name.length()
    }
    let total = p.additions + p.deletions
    if total > max_change {
      max_change = total
    }
  }
  // git apply.c: cap name width at 50
  let name_width = if max_len > 50 { 50 } else { max_len }
  // git apply.c: graph_max = (name_width + max_change > 70) ? 70 - name_width : max_change
  let graph_max = if name_width + max_change > 70 {
    70 - name_width
  } else {
    max_change
  }
  let mut total_add = 0
  let mut total_del = 0
  for p in patches {
    let name = if p.display_name.length() > name_width {
      // Truncate with "..." prefix, find slash boundary
      let skip = p.display_name.length() + 3 - name_width
      let rest = String::unsafe_substring(
        p.display_name,
        start=skip,
        end=p.display_name.length(),
      )
      // Try to find a '/' to make a cleaner break
      let mut slash_pos = -1
      for i = 0; i < rest.length(); i = i + 1 {
        if rest[i] == '/' {
          slash_pos = i
          break
        }
      }
      if slash_pos >= 0 {
        "..." +
        String::unsafe_substring(rest, start=slash_pos, end=rest.length())
      } else {
        "..." + rest
      }
    } else {
      p.display_name
    }
    let total = p.additions + p.deletions
    // Scale add/del for graph (git apply.c formula)
    let mut add_graph = p.additions
    let mut del_graph = p.deletions
    if max_change > 0 {
      let scaled_total = (total * graph_max + max_change / 2) / max_change
      add_graph = (p.additions * graph_max + max_change / 2) / max_change
      del_graph = scaled_total - add_graph
    }
    let name_padded = pad_right(name, name_width)
    let count_str = pad_left(total.to_string(), 5)
    let plus_str = "+".repeat(add_graph)
    let minus_str = "-".repeat(del_graph)
    println(" \{name_padded} |\{count_str} \{plus_str}\{minus_str}")
    total_add += p.additions
    total_del += p.deletions
  }
  // Summary line (git: print_stat_summary)
  let nfiles = patches.length()
  let files_word = if nfiles == 1 { "file changed" } else { "files changed" }
  let ins_word = if total_add == 1 { "insertion(+)" } else { "insertions(+)" }
  let del_word = if total_del == 1 { "deletion(-)" } else { "deletions(-)" }
  if total_add > 0 && total_del > 0 {
    println(
      " \{nfiles} \{files_word}, \{total_add} \{ins_word}, \{total_del} \{del_word}",
    )
  } else if total_add > 0 {
    println(" \{nfiles} \{files_word}, \{total_add} \{ins_word}")
  } else if total_del > 0 {
    println(" \{nfiles} \{files_word}, \{total_del} \{del_word}")
  } else {
    println(" \{nfiles} \{files_word}, 0 insertions(+), 0 deletions(-)")
  }
  // --summary output (git apply.c: summary_patch_list)
  if summary {
    for p in patches {
      if p.is_new {
        if p.new_mode != "" {
          println(" create mode \{p.new_mode} \{p.new_name}")
        } else {
          println(" create \{p.new_name}")
        }
      } else if p.is_delete {
        if p.old_mode != "" {
          println(" delete mode \{p.old_mode} \{p.old_name}")
        } else {
          println(" delete \{p.old_name}")
        }
      } else if p.is_rename || p.is_copy {
        let renamecopy = if p.is_rename { "rename" } else { "copy" }
        let display = @apply.make_rename_display(p.old_name, p.new_name)
        println(" \{renamecopy} \{display} (\{p.similarity_index}%)")
        // Also show mode change without name
        if p.old_mode != "" && p.new_mode != "" && p.old_mode != p.new_mode {
          println(" mode change \{p.old_mode} => \{p.new_mode}")
        }
      } else if p.dissimilarity_index > 0 {
        println(" rewrite \{p.new_name} (\{p.dissimilarity_index}%)")
        // Also show mode change without name
        if p.old_mode != "" && p.new_mode != "" && p.old_mode != p.new_mode {
          println(" mode change \{p.old_mode} => \{p.new_mode}")
        }
        // Regular file: show mode change with name
      } else if p.old_mode != "" && p.new_mode != "" && p.old_mode != p.new_mode {
        println(" mode change \{p.old_mode} => \{p.new_mode} \{p.new_name}")
      }
    }
  }
}

///|
async fn check_corrupt_hunk_headers(patch : String) -> Unit {
  let mut line_num = 0
  for line_view in patch.split("\n") {
    line_num += 1
    let line = line_view.to_string()
    if line.has_prefix("@@ -") {
      // Parse @@ -N,N +N,N @@ and check for overflow
      let rest = String::unsafe_substring(line, start=4, end=line.length())
      if has_overflow_number(rest) {
        eprint_line("error: corrupt patch at line \{line_num}")
        @sys.exit(128)
      }
    }
  }
}

///|
fn has_overflow_number(s : String) -> Bool {
  // Check if any number in the hunk header overflows Int
  // Numbers larger than ~10 digits are suspicious
  let mut i = 0
  while i < s.length() {
    if s[i] >= '0' && s[i] <= '9' {
      let start = i
      while i < s.length() && s[i] >= '0' && s[i] <= '9' {
        i += 1
      }
      let num_len = i - start
      // Any number with more than 10 digits definitely overflows 32-bit
      if num_len > 10 {
        return true
      }
      if num_len == 10 {
        let num_str = String::unsafe_substring(s, start~, end=i)
        // Compare against "2147483647" (INT32_MAX)
        if num_str > "2147483647" {
          return true
        }
      }
    } else {
      i += 1
    }
  }
  false
}

///|
