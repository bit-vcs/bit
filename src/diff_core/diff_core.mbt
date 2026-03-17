///| Pure diff algorithms — Myers diff, unified diff output, diff stat.
///  No git/repository dependencies. Operates on strings and bytes.

///|
pub(all) enum DiffEditOp {
  Keep(Int, Int) // old_idx, new_idx
  Delete(Int) // old_idx
  Insert(Int) // new_idx
}

///|
/// Myers diff algorithm. Computes the shortest edit script between two arrays of lines.
pub fn myers_diff(
  old : Array[String],
  new : Array[String],
) -> Array[DiffEditOp] {
  let n = old.length()
  let m = new.length()
  if n == 0 && m == 0 {
    return []
  }
  if n == 0 {
    return Array::makei(m, fn(j) { DiffEditOp::Insert(j) })
  }
  if m == 0 {
    return Array::makei(n, fn(i) { DiffEditOp::Delete(i) })
  }
  let max = n + m
  let size = 2 * max + 1
  let v : Array[Int] = Array::make(size, 0)
  let traces : Array[Array[Int]] = []
  let mut found = false
  let mut final_d = 0
  for d = 0; d <= max; d = d + 1 {
    traces.push(v.copy())
    for k = -d; k <= d; k = k + 2 {
      let idx = k + max
      let mut x = if k == -d || (k != d && v[idx - 1] < v[idx + 1]) {
        v[idx + 1]
      } else {
        v[idx - 1] + 1
      }
      let mut y = x - k
      while x < n && y < m && old[x] == new[y] {
        x = x + 1
        y = y + 1
      }
      v[idx] = x
      if x >= n && y >= m {
        final_d = d
        found = true
        break
      }
    }
    if found {
      break
    }
  }
  let edits : Array[DiffEditOp] = []
  let mut cx = n
  let mut cy = m
  for d = final_d; d > 0; d = d - 1 {
    let prev_v = traces[d]
    let k = cx - cy
    let idx = k + max
    let prev_k = if k == -d || (k != d && prev_v[idx - 1] < prev_v[idx + 1]) {
      k + 1
    } else {
      k - 1
    }
    let prev_x = prev_v[prev_k + max]
    let prev_y = prev_x - prev_k
    while cx > prev_x && cy > prev_y {
      cx = cx - 1
      cy = cy - 1
      edits.push(DiffEditOp::Keep(cx, cy))
    }
    if cx > prev_x {
      cx = cx - 1
      edits.push(DiffEditOp::Delete(cx))
    } else if cy > prev_y {
      cy = cy - 1
      edits.push(DiffEditOp::Insert(cy))
    }
  }
  while cx > 0 && cy > 0 {
    cx = cx - 1
    cy = cy - 1
    edits.push(DiffEditOp::Keep(cx, cy))
  }
  edits.rev()
}

///|
/// Split bytes into lines, removing trailing empty line if content ends with newline.
pub fn split_lines(data : Bytes) -> Array[String] {
  let text = @utf8.decode_lossy(data[:])
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    lines.push(line_view.to_string())
  }
  if text.has_suffix("\n") &&
    lines.length() > 0 &&
    lines[lines.length() - 1].length() == 0 {
    ignore(lines.pop())
  }
  lines
}

///|
/// Format a unified diff hunk range (e.g., "1,3" or "5").
pub fn format_range(start : Int, count : Int) -> String {
  if count == 0 {
    "\{start},0"
  } else if count == 1 {
    start.to_string()
  } else {
    "\{start},\{count}"
  }
}

///|
/// Generate unified diff hunks from old and new content bytes.
pub fn unified_hunks(
  out : Array[String],
  old_content : Bytes?,
  new_content : Bytes?,
  context_lines? : Int = 3,
) -> Unit {
  guard old_content is Some(_) || new_content is Some(_) else { return }
  let old_lines = match old_content {
    Some(data) => split_lines(data)
    None => []
  }
  let new_lines = match new_content {
    Some(data) => split_lines(data)
    None => []
  }
  let old_has_trailing_nl = match old_content {
    Some(data) => data.length() > 0 && data[data.length() - 1] == b'\n'
    None => true
  }
  let new_has_trailing_nl = match new_content {
    Some(data) => data.length() > 0 && data[data.length() - 1] == b'\n'
    None => true
  }
  if old_lines.length() == 0 && new_lines.length() == 0 {
    return
  }
  let edits = myers_diff(old_lines, new_lines)
  let annotated : Array[(Int, Int, Int, String)] = []
  for edit in edits {
    match edit {
      DiffEditOp::Keep(oi, ni) => annotated.push((0, oi, ni, old_lines[oi]))
      DiffEditOp::Delete(oi) => annotated.push((1, oi, -1, old_lines[oi]))
      DiffEditOp::Insert(ni) => annotated.push((2, -1, ni, new_lines[ni]))
    }
  }
  let changes : Array[(Int, Int)] = []
  let mut i = 0
  while i < annotated.length() {
    if annotated[i].0 != 0 {
      let start = i
      while i < annotated.length() && annotated[i].0 != 0 {
        i += 1
      }
      changes.push((start, i))
    } else {
      i += 1
    }
  }
  if changes.length() == 0 {
    return
  }
  let hunks : Array[(Int, Int)] = []
  let mut hunk_start = if changes[0].0 > context_lines {
    changes[0].0 - context_lines
  } else {
    0
  }
  let mut hunk_end = if changes[0].1 + context_lines < annotated.length() {
    changes[0].1 + context_lines
  } else {
    annotated.length()
  }
  for ci = 1; ci < changes.length(); ci = ci + 1 {
    let (cs, ce) = changes[ci]
    let ctx_start = if cs > context_lines { cs - context_lines } else { 0 }
    if ctx_start <= hunk_end {
      hunk_end = if ce + context_lines < annotated.length() {
        ce + context_lines
      } else {
        annotated.length()
      }
    } else {
      hunks.push((hunk_start, hunk_end))
      hunk_start = ctx_start
      hunk_end = if ce + context_lines < annotated.length() {
        ce + context_lines
      } else {
        annotated.length()
      }
    }
  }
  hunks.push((hunk_start, hunk_end))
  for hunk in hunks {
    let (hs, he) = hunk
    let mut old_start = 0
    let mut old_count = 0
    let mut new_start = 0
    let mut new_count = 0
    let mut first_old = true
    let mut first_new = true
    for j = hs; j < he; j = j + 1 {
      let (kind, oi, ni, _) = annotated[j]
      match kind {
        0 => {
          if first_old {
            old_start = oi + 1
            first_old = false
          }
          if first_new {
            new_start = ni + 1
            first_new = false
          }
          old_count += 1
          new_count += 1
        }
        1 => {
          if first_old {
            old_start = oi + 1
            first_old = false
          }
          old_count += 1
        }
        _ => {
          if first_new {
            new_start = ni + 1
            first_new = false
          }
          new_count += 1
        }
      }
    }
    if first_old {
      old_start = if old_lines.length() == 0 { 0 } else { old_count }
    }
    if first_new {
      new_start = if new_lines.length() == 0 { 0 } else { new_count }
    }
    let old_range = format_range(old_start, old_count)
    let new_range = format_range(new_start, new_count)
    out.push("@@ -\{old_range} +\{new_range} @@")
    let mut last_del_is_eof = false
    let mut last_ins_is_eof = false
    for j = hs; j < he; j = j + 1 {
      let (kind, oi, ni, text) = annotated[j]
      match kind {
        0 => {
          if last_del_is_eof {
            out.push("\\ No newline at end of file")
            last_del_is_eof = false
          }
          if last_ins_is_eof {
            out.push("\\ No newline at end of file")
            last_ins_is_eof = false
          }
          out.push(" " + text)
        }
        1 => {
          if last_ins_is_eof {
            out.push("\\ No newline at end of file")
            last_ins_is_eof = false
          }
          out.push("-" + text)
          last_del_is_eof = not(old_has_trailing_nl) &&
            oi == old_lines.length() - 1
        }
        _ => {
          if last_del_is_eof {
            out.push("\\ No newline at end of file")
            last_del_is_eof = false
          }
          out.push("+" + text)
          last_ins_is_eof = not(new_has_trailing_nl) &&
            ni == new_lines.length() - 1
        }
      }
    }
    if last_del_is_eof || last_ins_is_eof {
      out.push("\\ No newline at end of file")
    }
  }
}

///|
/// Count lines in byte content.
pub fn count_lines(data : Bytes) -> Int {
  let mut count = 0
  for b in data {
    if b == b'\n' {
      count = count + 1
    }
  }
  if data.length() > 0 && data[data.length() - 1] != b'\n' {
    count = count + 1
  }
  count
}
