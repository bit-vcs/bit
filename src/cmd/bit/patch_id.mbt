///| git patch-id - compute a stable patch identifier

///|
async fn handle_patch_id(args : Array[String]) -> Unit raise Error {
  // Parse options (--stable is default, --unstable accepted but same behavior)
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git patch-id [--stable | --unstable | --verbatim]",
          summary="Compute a stable patch identifier for a diff.",
        )
        return
      }
      "--stable" | "--unstable" | "--verbatim" => ()
      _ => ()
    }
  }
  let input = decode_bytes(read_all_stdin())
  let results = patch_id_compute(input)
  for result in results {
    let (pid, commit_id) = result
    print_line("\{pid} \{commit_id}")
  }
}

///|
fn patch_id_compute(input : String) -> Array[(String, String)] {
  let results : Array[(String, String)] = []
  let lines : Array[String] = []
  for line_view in input.split("\n") {
    lines.push(line_view.to_string())
  }
  // Process the diff to find individual patches (separated by "commit " or "diff --git")
  let normalized : Array[String] = []
  let mut current_commit = "0000000000000000000000000000000000000000"
  let mut has_diff = false
  for line in lines {
    if line.has_prefix("commit ") {
      // Flush previous patch if any
      if has_diff && normalized.length() > 0 {
        let pid = patch_id_hash(normalized)
        results.push((pid, current_commit))
        normalized.clear()
        has_diff = false
      }
      let hex = String::unsafe_substring(
        line,
        start=7,
        end=if line.length() >= 47 { 47 } else { line.length() },
      )
      current_commit = hex
      continue
    }
    if line.has_prefix("diff --git ") {
      if has_diff && normalized.length() > 0 {
        let pid = patch_id_hash(normalized)
        results.push((pid, current_commit))
        normalized.clear()
      }
      has_diff = true
      // Include the diff header (normalized)
      normalized.push(line)
      continue
    }
    if !has_diff {
      continue
    }
    // Skip index lines
    if line.has_prefix("index ") {
      continue
    }
    // Normalize @@ hunk headers: strip line numbers
    if line.has_prefix("@@ ") {
      normalized.push("@@")
      continue
    }
    // Skip blank context lines
    if line.length() == 0 || line == " " {
      continue
    }
    // Strip trailing whitespace
    let trimmed = patch_id_rtrim(line)
    if trimmed.length() > 0 {
      normalized.push(trimmed)
    }
  }
  // Flush last patch
  if has_diff && normalized.length() > 0 {
    let pid = patch_id_hash(normalized)
    results.push((pid, current_commit))
  }
  results
}

///|
fn patch_id_hash(lines : Array[String]) -> String {
  let content = lines.join("\n")
  let bytes = Bytes::from_array(
    FixedArray::makei(content.length(), fn(i) { content[i].to_int().to_byte() }),
  )
  @bitcore.sha1(bytes).to_hex()
}

///|
fn patch_id_rtrim(s : String) -> String {
  let chars = s.to_array()
  let mut end = chars.length()
  while end > 0 {
    let c = chars[end - 1]
    if c == ' ' || c == '\t' || c == '\r' {
      end -= 1
    } else {
      break
    }
  }
  if end == chars.length() {
    return s
  }
  String::unsafe_substring(s, start=0, end~)
}
