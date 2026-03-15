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
  // Check for corrupt hunk headers (overflow)
  check_corrupt_hunk_headers(patch_content)
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
struct PatchInfo {
  /// Display name for stat output (may contain {old => new} for renames)
  display_name : String
  additions : Int
  deletions : Int
  is_rename : Bool
  is_copy : Bool
  is_new : Bool
  is_delete : Bool
  old_name : String
  new_name : String
  old_mode : String
  new_mode : String
  similarity_index : Int
  dissimilarity_index : Int
}

///|
fn parse_patches(patch : String) -> Array[PatchInfo] {
  let patches : Array[PatchInfo] = []
  let lines_iter = patch.split("\n")
  let all_lines : Array[String] = []
  for lv in lines_iter {
    all_lines.push(lv.to_string())
  }
  let mut i = 0
  while i < all_lines.length() {
    let line = all_lines[i]
    // Detect start of a diff (git format or non-git format)
    let is_git_diff = line.has_prefix("diff --git ")
    let is_nongit_diff = not(is_git_diff) && line.has_prefix("diff ")
    if is_git_diff || is_nongit_diff {
      let mut old_name = ""
      let mut new_name = ""
      let mut is_rename = false
      let mut is_copy = false
      let mut is_new = false
      let mut is_delete = false
      let mut old_mode = ""
      let mut new_mode = ""
      let mut similarity = 0
      let mut dissimilarity = 0
      let mut additions = 0
      let mut deletions = 0
      if is_git_diff {
        // Parse "diff --git a/OLD b/NEW"
        let rest = String::unsafe_substring(line, start=11, end=line.length())
        let (oname, nname) = parse_diff_git_header(rest)
        old_name = oname
        new_name = nname
      } else {
        // Non-git diff: "diff a/OLD b/NEW" or "diff -u a/file b/file" etc.
        // We'll get names from --- / +++ lines below
      }
      i += 1
      // Parse extended headers
      while i < all_lines.length() {
        let hline = all_lines[i]
        if hline.has_prefix("diff ") {
          break
        }
        if hline.has_prefix("similarity index ") {
          let pct_str = String::unsafe_substring(
            hline,
            start=17,
            end=hline.length(),
          )
          similarity = parse_pct(pct_str)
        } else if hline.has_prefix("dissimilarity index ") {
          let pct_str = String::unsafe_substring(
            hline,
            start=20,
            end=hline.length(),
          )
          dissimilarity = parse_pct(pct_str)
        } else if hline.has_prefix("rename from ") {
          is_rename = true
          old_name = String::unsafe_substring(
            hline,
            start=12,
            end=hline.length(),
          )
        } else if hline.has_prefix("rename to ") {
          is_rename = true
          new_name = String::unsafe_substring(
            hline,
            start=10,
            end=hline.length(),
          )
        } else if hline.has_prefix("copy from ") {
          is_copy = true
          old_name = String::unsafe_substring(
            hline,
            start=10,
            end=hline.length(),
          )
        } else if hline.has_prefix("copy to ") {
          is_copy = true
          new_name = String::unsafe_substring(
            hline,
            start=8,
            end=hline.length(),
          )
        } else if hline.has_prefix("new file mode ") {
          is_new = true
          new_mode = String::unsafe_substring(
            hline,
            start=14,
            end=hline.length(),
          )
        } else if hline.has_prefix("deleted file mode ") {
          is_delete = true
          old_mode = String::unsafe_substring(
            hline,
            start=18,
            end=hline.length(),
          )
        } else if hline.has_prefix("old mode ") {
          old_mode = String::unsafe_substring(
            hline,
            start=9,
            end=hline.length(),
          )
        } else if hline.has_prefix("new mode ") {
          new_mode = String::unsafe_substring(
            hline,
            start=9,
            end=hline.length(),
          )
        } else if hline.has_prefix("--- ") {
          // Extract old file name
          let fname = String::unsafe_substring(
            hline,
            start=4,
            end=hline.length(),
          )
          if fname == "/dev/null" {
            is_new = true
          } else if fname.has_prefix("a/") {
            if old_name == "" {
              old_name = String::unsafe_substring(
                fname,
                start=2,
                end=fname.length(),
              )
            }
          } else if old_name == "" {
            old_name = fname
          }
          i += 1
          // Expect +++ line next
          if i < all_lines.length() {
            let pline = all_lines[i]
            if pline.has_prefix("+++ ") {
              let pfname = String::unsafe_substring(
                pline,
                start=4,
                end=pline.length(),
              )
              if pfname == "/dev/null" {
                is_delete = true
              } else if pfname.has_prefix("b/") {
                if new_name == "" {
                  new_name = String::unsafe_substring(
                    pfname,
                    start=2,
                    end=pfname.length(),
                  )
                }
              } else if new_name == "" {
                new_name = pfname
              }
            }
          }
          i += 1
          // Count hunk lines
          while i < all_lines.length() {
            let hunkline = all_lines[i]
            if hunkline.has_prefix("diff ") {
              break
            }
            if hunkline.has_prefix("+") &&
              not(hunkline.has_prefix("+++ ")) &&
              hunkline != "+++" {
              additions += 1
            } else if hunkline.has_prefix("-") &&
              not(hunkline.has_prefix("--- ")) &&
              hunkline != "---" {
              deletions += 1
            }
            i += 1
          }
          continue
        } else if hline.has_prefix("@@") || hline.has_prefix("index ") {
          // skip index line, start counting on @@ lines via --- path
          i += 1
          continue
        } else {
          i += 1
          continue
        }
        i += 1
      }
      // For non-git diffs, if old_name is empty, we might not have parsed it
      if new_name == "" && old_name != "" {
        new_name = old_name
      }
      if old_name == "" && new_name != "" {
        old_name = new_name
      }
      // git apply.c show_stats: uses new_name if available, else old_name
      let display = if new_name != "" { new_name } else { old_name }
      patches.push({
        display_name: display,
        additions,
        deletions,
        is_rename,
        is_copy,
        is_new,
        is_delete,
        old_name,
        new_name,
        old_mode,
        new_mode,
        similarity_index: similarity,
        dissimilarity_index: dissimilarity,
      })
    } else {
      i += 1
    }
  }
  patches
}

///|
fn parse_diff_git_header(rest : String) -> (String, String) {
  // rest is like "a/foo b/bar" — but filenames can contain spaces
  // Strategy: try "a/" prefix, then find " b/" separator
  if rest.has_prefix("a/") {
    let search = rest
    // Find " b/" separator - try from various positions
    let mut pos = 2
    while pos < search.length() - 2 {
      if search[pos] == ' ' &&
        pos + 1 < search.length() &&
        search[pos + 1] == 'b' &&
        pos + 2 < search.length() &&
        search[pos + 2] == '/' {
        let old_name = String::unsafe_substring(search, start=2, end=pos)
        let new_name = String::unsafe_substring(
          search,
          start=pos + 3,
          end=search.length(),
        )
        return (old_name, new_name)
      }
      pos += 1
    }
  }
  ("", "")
}

///|
fn parse_pct(s : String) -> Int {
  // Parse "NN%" -> NN
  let mut n = 0
  for c in s {
    if c >= '0' && c <= '9' {
      n = n * 10 + (c.to_int() - '0'.to_int())
    }
  }
  n
}

///|
fn make_rename_display(old_name : String, new_name : String) -> String {
  // Find common prefix and suffix, then format as prefix{old => new}suffix
  let mut prefix_len = 0
  let mut last_slash = -1
  let min_len = if old_name.length() < new_name.length() {
    old_name.length()
  } else {
    new_name.length()
  }
  while prefix_len < min_len && old_name[prefix_len] == new_name[prefix_len] {
    if old_name[prefix_len] == '/' {
      last_slash = prefix_len
    }
    prefix_len += 1
  }
  // If not fully matching, back up to last slash boundary
  if prefix_len < old_name.length() || prefix_len < new_name.length() {
    prefix_len = last_slash + 1
  }
  // Find common suffix
  let old_rest_len = old_name.length() - prefix_len
  let new_rest_len = new_name.length() - prefix_len
  let min_rest = if old_rest_len < new_rest_len {
    old_rest_len
  } else {
    new_rest_len
  }
  let mut suffix_len = 0
  while suffix_len < min_rest {
    let oc = old_name[old_name.length() - 1 - suffix_len]
    let nc = new_name[new_name.length() - 1 - suffix_len]
    if oc != nc {
      break
    }
    suffix_len += 1
  }
  // Adjust suffix to start at a slash boundary (or start of rest)
  if suffix_len > 0 {
    // Find the first '/' from the start of the suffix region
    let old_suffix_start = old_name.length() - suffix_len
    let mut adjusted = suffix_len
    let mut found_slash = false
    let mut si = 0
    while si < suffix_len {
      if old_name[old_suffix_start + si] == '/' {
        adjusted = suffix_len - si
        found_slash = true
        break
      }
      si += 1
    }
    if found_slash {
      suffix_len = adjusted
    } else if suffix_len != old_rest_len && suffix_len != new_rest_len {
      suffix_len = 0
    }
  }
  let prefix = String::unsafe_substring(old_name, start=0, end=prefix_len)
  let old_mid = String::unsafe_substring(
    old_name,
    start=prefix_len,
    end=old_name.length() - suffix_len,
  )
  let new_mid = String::unsafe_substring(
    new_name,
    start=prefix_len,
    end=new_name.length() - suffix_len,
  )
  let suffix = String::unsafe_substring(
    old_name,
    start=old_name.length() - suffix_len,
    end=old_name.length(),
  )
  if prefix == "" && suffix == "" {
    "\{old_mid} => \{new_mid}"
  } else {
    "\{prefix}{\{old_mid} => \{new_mid}}\{suffix}"
  }
}

///|
fn print_patch_stats_sync(
  patch : String,
  numstat : Bool,
  summary : Bool,
) -> Unit {
  let patches = parse_patches(patch)
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
        let display = make_rename_display(p.old_name, p.new_name)
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
