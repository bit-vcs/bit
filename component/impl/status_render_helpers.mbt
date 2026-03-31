///| WASM Component status rendering helpers

///|
fn porcelain_lines_from_status(s : StatusResult) -> Array[String] {
  let lines : Array[String] = []
  for p in s.staged_added {
    lines.push("A  " + p)
  }
  for p in s.staged_modified {
    lines.push("M  " + p)
  }
  for p in s.staged_deleted {
    lines.push("D  " + p)
  }
  for p in s.unstaged_modified {
    lines.push(" M " + p)
  }
  for p in s.unstaged_deleted {
    lines.push(" D " + p)
  }
  for p in s.untracked {
    lines.push("?? " + p)
  }
  lines
}

///|
fn sort_status_paths(paths : Array[String]) -> Unit {
  paths.sort_by((a, b) => String::lexical_compare(a, b))
}
