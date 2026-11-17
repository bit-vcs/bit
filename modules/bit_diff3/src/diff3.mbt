///| Content-level 3-way merge using Myers diff + diff3 algorithm

///|
pub(all) enum ConflictStyle {
  Merge
  Diff3
}

///|
pub(all) enum MergeFavor {
  NoFavor
  FavorOurs
  FavorTheirs
  FavorUnion
}

///|
pub(all) struct ContentMergeOptions {
  conflict_style : ConflictStyle
  ours_label : String
  base_label : String
  theirs_label : String
  marker_size : Int
  favor : MergeFavor
}

///|
pub fn ContentMergeOptions::default() -> ContentMergeOptions {
  {
    conflict_style: ConflictStyle::Merge,
    ours_label: "HEAD",
    base_label: "parent",
    theirs_label: "incoming",
    marker_size: 7,
    favor: MergeFavor::NoFavor,
  }
}

///|
pub fn ContentMergeOptions::favor_ours() -> ContentMergeOptions {
  { ..ContentMergeOptions::default(), favor: MergeFavor::FavorOurs }
}

///|
pub fn ContentMergeOptions::favor_theirs() -> ContentMergeOptions {
  { ..ContentMergeOptions::default(), favor: MergeFavor::FavorTheirs }
}

///|
pub fn ContentMergeOptions::favor_union() -> ContentMergeOptions {
  { ..ContentMergeOptions::default(), favor: MergeFavor::FavorUnion }
}

///|
pub fn ContentMergeOptions::new(
  conflict_style? : ConflictStyle = ConflictStyle::Merge,
  ours_label? : String = "HEAD",
  base_label? : String = "parent",
  theirs_label? : String = "incoming",
  marker_size? : Int = 7,
  favor? : MergeFavor = MergeFavor::NoFavor,
) -> ContentMergeOptions {
  { conflict_style, ours_label, base_label, theirs_label, marker_size, favor }
}

///|
pub fn ContentMergeOptions::with_diff3(
  self : ContentMergeOptions,
) -> ContentMergeOptions {
  { ..self, conflict_style: ConflictStyle::Diff3 }
}

///|
pub fn ContentMergeOptions::with_labels(
  self : ContentMergeOptions,
  ours~ : String,
  base~ : String,
  theirs~ : String,
) -> ContentMergeOptions {
  { ..self, ours_label: ours, base_label: base, theirs_label: theirs }
}

///|
pub fn ContentMergeOptions::with_marker_size(
  self : ContentMergeOptions,
  size : Int,
) -> ContentMergeOptions {
  { ..self, marker_size: size }
}

///|
pub(all) struct ContentMergeResult {
  content : String
  has_conflicts : Bool
  conflict_count : Int
}

///|
priv enum EditOp {
  Keep(Int, Int)
  Delete(Int)
  Insert(Int)
}

///|
priv struct ChangeRange {
  base_start : Int
  base_end : Int
  new_start : Int
  new_end : Int
}

///|
priv enum Diff3Section {
  Clean(Array[String])
  Conflict(
    ours~ : Array[String],
    base~ : Array[String],
    theirs~ : Array[String]
  )
}

///|
fn split_lines(text : String) -> Array[String] {
  if text.length() == 0 {
    return []
  }
  let lines : Array[String] = []
  let sb = StringBuilder()
  for c in text {
    sb.write_char(c)
    if c == '\n' {
      lines.push(sb.to_string())
      sb.reset()
    }
  }
  let remaining = sb.to_string()
  if remaining.length() > 0 {
    lines.push(remaining)
  }
  lines
}

///|
fn myers_diff(old : Array[String], new : Array[String]) -> Array[EditOp] {
  let n = old.length()
  let m = new.length()
  if n == 0 && m == 0 {
    return []
  }
  if n == 0 {
    return Array::makei(m, fn(j) { EditOp::Insert(j) })
  }
  if m == 0 {
    return Array::makei(n, fn(i) { EditOp::Delete(i) })
  }
  let max = n + m
  let size = 2 * max + 1
  // v[k + max] = x-coordinate of the furthest reaching path for diagonal k
  let v : Array[Int] = Array::make(size, 0)
  // Store traces for backtracking
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
  // Backtrack to find the edit sequence
  let edits : Array[EditOp] = []
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
    // Diagonal moves (matches)
    while cx > prev_x && cy > prev_y {
      cx = cx - 1
      cy = cy - 1
      edits.push(EditOp::Keep(cx, cy))
    }
    if cx > prev_x {
      cx = cx - 1
      edits.push(EditOp::Delete(cx))
    } else if cy > prev_y {
      cy = cy - 1
      edits.push(EditOp::Insert(cy))
    }
  }
  // Remaining diagonal moves at d=0
  while cx > 0 && cy > 0 {
    cx = cx - 1
    cy = cy - 1
    edits.push(EditOp::Keep(cx, cy))
  }
  edits.rev()
}

///|
fn extract_changes(edits : Array[EditOp]) -> Array[ChangeRange] {
  let changes : Array[ChangeRange] = []
  let mut i = 0
  let len = edits.length()
  while i < len {
    match edits[i] {
      Keep(_, _) => i = i + 1
      _ => {
        let mut base_start = -1
        let mut base_end = -1
        let mut new_start = -1
        let mut new_end = -1
        while i < len {
          match edits[i] {
            Keep(_, _) => break
            Delete(bi) => {
              if base_start < 0 {
                base_start = bi
              }
              base_end = bi + 1
              i = i + 1
            }
            Insert(ni) => {
              if new_start < 0 {
                new_start = ni
              }
              new_end = ni + 1
              i = i + 1
            }
          }
        }
        // For insert-only changes, base range is empty at the insert point
        // We need to find the base position from the surrounding context
        if base_start < 0 && base_end < 0 {
          // Pure insert - find position from the new_start
          // The base position is where the insert happens in the base sequence
          // Look at the previous Keep to determine base position
          let pos = find_base_pos_for_insert(edits, i)
          base_start = pos
          base_end = pos
        }
        if base_start < 0 {
          base_start = base_end
        }
        if new_start < 0 && new_end < 0 {
          // Pure delete
          let pos = find_new_pos_for_delete(edits, i)
          new_start = pos
          new_end = pos
        }
        if new_start < 0 {
          new_start = new_end
        }
        changes.push({ base_start, base_end, new_start, new_end })
      }
    }
  }
  changes
}

///|
fn find_base_pos_for_insert(edits : Array[EditOp], current_idx : Int) -> Int {
  // Look backward for the last Keep or Delete to find base position
  let mut j = current_idx - 1
  while j >= 0 {
    match edits[j] {
      Keep(bi, _) => return bi + 1
      Delete(bi) => return bi + 1
      _ => j = j - 1
    }
  }
  0
}

///|
fn find_new_pos_for_delete(edits : Array[EditOp], current_idx : Int) -> Int {
  let mut j = current_idx - 1
  while j >= 0 {
    match edits[j] {
      Keep(_, ni) => return ni + 1
      Insert(ni) => return ni + 1
      _ => j = j - 1
    }
  }
  0
}

///|
fn ranges_overlap(a : ChangeRange, b : ChangeRange) -> Bool {
  // Empty ranges at the same position count as overlapping (both insert at same point)
  if a.base_start == a.base_end && b.base_start == b.base_end {
    a.base_start == b.base_start
  } else if a.base_start == a.base_end {
    // An insert touching either edge of the other side's changed region is
    // a conflict too: the insert's context (the lines right around it) was
    // itself changed by the other side, so there is no unambiguous anchor
    // to place it against. Matches git's merge behavior of conflicting
    // rather than silently reordering/dropping content in this case.
    a.base_start >= b.base_start && a.base_start <= b.base_end
  } else if b.base_start == b.base_end {
    b.base_start >= a.base_start && b.base_start <= a.base_end
  } else {
    a.base_start < b.base_end && b.base_start < a.base_end
  }
}

///|
fn lines_equal(
  a : Array[String],
  a_start : Int,
  a_end : Int,
  b : Array[String],
  b_start : Int,
  b_end : Int,
) -> Bool {
  let a_len = a_end - a_start
  let b_len = b_end - b_start
  if a_len != b_len {
    return false
  }
  for i in 0..<a_len {
    if a[a_start + i] != b[b_start + i] {
      return false
    }
  }
  true
}

///|
fn slice_lines(lines : Array[String], start : Int, end : Int) -> Array[String] {
  let result : Array[String] = []
  for i in start..<end {
    result.push(lines[i])
  }
  result
}

///|
fn diff3_merge(
  base : Array[String],
  ours : Array[String],
  theirs : Array[String],
) -> Array[Diff3Section] {
  let edits_ours = myers_diff(base, ours)
  let edits_theirs = myers_diff(base, theirs)
  let changes_ours = extract_changes(edits_ours)
  let changes_theirs = extract_changes(edits_theirs)
  let sections : Array[Diff3Section] = []
  let mut oi = 0
  let mut ti = 0
  let mut base_pos = 0
  while oi < changes_ours.length() || ti < changes_theirs.length() {
    let ours_change = if oi < changes_ours.length() {
      Some(changes_ours[oi])
    } else {
      None
    }
    let theirs_change = if ti < changes_theirs.length() {
      Some(changes_theirs[ti])
    } else {
      None
    }
    match (ours_change, theirs_change) {
      (Some(o), Some(t)) =>
        if ranges_overlap(o, t) {
          // The conflict spans the union of every change (from either side)
          // that overlaps it, transitively; each side's text is its version
          // of that whole base range (unchanged lines it kept included).
          let mut s0 = if o.base_start < t.base_start {
            o.base_start
          } else {
            t.base_start
          }
          let mut e0 = if o.base_end > t.base_end { o.base_end } else { t.base_end }
          let mut o_last = oi
          let mut t_last = ti
          let mut grew = true
          while grew {
            grew = false
            let span = { base_start: s0, base_end: e0, new_start: 0, new_end: 0 }
            if o_last + 1 < changes_ours.length() &&
              ranges_overlap(changes_ours[o_last + 1], span) {
              o_last = o_last + 1
              let c = changes_ours[o_last]
              if c.base_end > e0 {
                e0 = c.base_end
              }
              if c.base_start < s0 {
                s0 = c.base_start
              }
              grew = true
            }
            if t_last + 1 < changes_theirs.length() &&
              ranges_overlap(changes_theirs[t_last + 1], span) {
              t_last = t_last + 1
              let c = changes_theirs[t_last]
              if c.base_end > e0 {
                e0 = c.base_end
              }
              if c.base_start < s0 {
                s0 = c.base_start
              }
              grew = true
            }
          }
          let overlap_start = s0
          let overlap_end = e0
          if base_pos < overlap_start {
            sections.push(
              Diff3Section::Clean(slice_lines(base, base_pos, overlap_start)),
            )
          }
          let of = changes_ours[oi]
          let ol = changes_ours[o_last]
          let tf = changes_theirs[ti]
          let tl = changes_theirs[t_last]
          let ours_lines = slice_lines(
            ours,
            of.new_start - (of.base_start - overlap_start),
            ol.new_end + (overlap_end - ol.base_end),
          )
          let theirs_lines = slice_lines(
            theirs,
            tf.new_start - (tf.base_start - overlap_start),
            tl.new_end + (overlap_end - tl.base_end),
          )
          // Check if both sides made the same change
          if lines_equal(
              ours_lines,
              0,
              ours_lines.length(),
              theirs_lines,
              0,
              theirs_lines.length(),
            ) {
            sections.push(Diff3Section::Clean(ours_lines))
          } else {
            let base_lines = slice_lines(base, overlap_start, overlap_end)
            sections.push(
              Diff3Section::Conflict(
                ours=ours_lines,
                base=base_lines,
                theirs=theirs_lines,
              ),
            )
          }
          base_pos = overlap_end
          oi = o_last + 1
          ti = t_last + 1
        } else if o.base_start <= t.base_start {
          // Ours comes first, no overlap
          if base_pos < o.base_start {
            sections.push(
              Diff3Section::Clean(slice_lines(base, base_pos, o.base_start)),
            )
          }
          sections.push(
            Diff3Section::Clean(slice_lines(ours, o.new_start, o.new_end)),
          )
          base_pos = o.base_end
          oi = oi + 1
        } else {
          // Theirs comes first, no overlap
          if base_pos < t.base_start {
            sections.push(
              Diff3Section::Clean(slice_lines(base, base_pos, t.base_start)),
            )
          }
          sections.push(
            Diff3Section::Clean(slice_lines(theirs, t.new_start, t.new_end)),
          )
          base_pos = t.base_end
          ti = ti + 1
        }
      (Some(o), None) => {
        if base_pos < o.base_start {
          sections.push(
            Diff3Section::Clean(slice_lines(base, base_pos, o.base_start)),
          )
        }
        sections.push(
          Diff3Section::Clean(slice_lines(ours, o.new_start, o.new_end)),
        )
        base_pos = o.base_end
        oi = oi + 1
      }
      (None, Some(t)) => {
        if base_pos < t.base_start {
          sections.push(
            Diff3Section::Clean(slice_lines(base, base_pos, t.base_start)),
          )
        }
        sections.push(
          Diff3Section::Clean(slice_lines(theirs, t.new_start, t.new_end)),
        )
        base_pos = t.base_end
        ti = ti + 1
      }
      (None, None) => break
    }
  }
  // Remaining base lines
  if base_pos < base.length() {
    sections.push(
      Diff3Section::Clean(slice_lines(base, base_pos, base.length())),
    )
  }
  sections
}

///|
fn render_marker(
  ch : Char,
  size : Int,
  label : String,
  cr? : Bool = false,
) -> String {
  let sb = StringBuilder()
  for _ in 0..<size {
    sb.write_char(ch)
  }
  if label.length() > 0 {
    sb.write_char(' ')
    sb.write_string(label)
  }
  if cr {
    sb.write_char('\r')
  }
  sb.write_char('\n')
  sb.to_string()
}

///|
/// git's is_eol_crlf: 1 when line `i` ends in CRLF, 0 for LF, -1 when it
/// cannot tell (an empty file, or a single line without an end of line).
fn eol_crlf(lines : Array[String], i : Int) -> Int {
  let n = lines.length()
  if n == 0 {
    return -1
  }
  let crlf = fn(l : String) { if l.has_suffix("\r\n") { 1 } else { 0 } }
  if i < n - 1 {
    return crlf(lines[i])
  }
  if lines[i].has_suffix("\n") {
    return crlf(lines[i])
  }
  if i == 0 {
    return -1
  }
  crlf(lines[i - 1])
}

///|
/// git's is_cr_needed: conflict markers follow the end-of-line style of the
/// line before the conflict (or the first line of ours / theirs), then of
/// the base's first line; LF when nothing decides.
fn conflict_needs_cr(
  prev_line : String?,
  ours : Array[String],
  theirs : Array[String],
  base : Array[String],
) -> Bool {
  let style = fn(file : Array[String]) {
    match prev_line {
      Some(l) => if l.has_suffix("\r\n") { 1 } else { 0 }
      None => eol_crlf(file, 0)
    }
  }
  let mut needs = style(ours)
  if needs != 0 {
    needs = style(theirs)
  }
  if needs != 0 {
    needs = eol_crlf(base, 0)
  }
  needs == 1
}

///|
pub fn content_merge(
  base_text : String,
  ours_text : String,
  theirs_text : String,
  options : ContentMergeOptions,
) -> ContentMergeResult {
  let base_lines = split_lines(base_text)
  let ours_lines = split_lines(ours_text)
  let theirs_lines = split_lines(theirs_text)
  let raw_sections = diff3_merge(base_lines, ours_lines, theirs_lines)
  // git's default merge level (XDL_MERGE_ZEALOUS) refines conflicts for the
  // plain "merge" style: lines both sides share move out of the markers,
  // and conflicts separated by at most 3 unchanged lines are joined again.
  let sections = match options.conflict_style {
    ConflictStyle::Merge => zealous_refine(raw_sections)
    ConflictStyle::Diff3 => raw_sections
  }
  let sb = StringBuilder()
  let mut conflict_count = 0
  // The line written just before a conflict (git's "preceding line").
  let mut prev_line : String? = None
  for section in sections {
    match section {
      Diff3Section::Clean(lines) =>
        for line in lines {
          sb.write_string(line)
          prev_line = Some(line)
        }
      Diff3Section::Conflict(ours~, base~, theirs~) =>
        match options.favor {
          MergeFavor::FavorOurs =>
            for line in ours {
              sb.write_string(line)
            }
          MergeFavor::FavorTheirs =>
            for line in theirs {
              sb.write_string(line)
            }
          MergeFavor::FavorUnion => {
            for line in ours {
              sb.write_string(line)
            }
            for line in theirs {
              sb.write_string(line)
            }
          }
          MergeFavor::NoFavor => {
            conflict_count = conflict_count + 1
            let cr = conflict_needs_cr(
              prev_line, ours_lines, theirs_lines, base_lines,
            )
            sb.write_string(
              render_marker('<', options.marker_size, options.ours_label, cr~),
            )
            write_conflict_section(sb, ours, cr~)
            match options.conflict_style {
              ConflictStyle::Diff3 => {
                sb.write_string(
                  render_marker(
                    '|',
                    options.marker_size,
                    options.base_label,
                    cr~,
                  ),
                )
                write_conflict_section(sb, base, cr~)
              }
              ConflictStyle::Merge => ()
            }
            sb.write_string(render_marker('=', options.marker_size, "", cr~))
            write_conflict_section(sb, theirs, cr~)
            sb.write_string(
              render_marker('>', options.marker_size, options.theirs_label, cr~),
            )
            prev_line = Some("\n")
          }
        }
    }
  }
  { content: sb.to_string(), has_conflicts: conflict_count > 0, conflict_count }
}

///|
pub fn is_binary_content(data : Bytes) -> Bool {
  let check_len = if data.length() < 8000 { data.length() } else { 8000 }
  for i in 0..<check_len {
    if data[i] == b'\x00' {
      return true
    }
  }
  false
}

///|
/// Write one side of a conflict: a last line without a newline gets one, so
/// the following marker starts its own line (as git does).
fn write_conflict_section(
  sb : StringBuilder,
  lines : Array[String],
  cr? : Bool = false,
) -> Unit {
  for line in lines {
    sb.write_string(line)
  }
  if lines.length() > 0 && !lines[lines.length() - 1].has_suffix("\n") {
    sb.write_string(if cr { "\r\n" } else { "\n" })
  }
}

///|
/// Refine and re-join conflict sections like git's xdl_refine_conflicts +
/// xdl_simplify_non_conflicts at XDL_MERGE_ZEALOUS.
fn zealous_refine(sections : Array[Diff3Section]) -> Array[Diff3Section] {
  // 1. Split each conflict along the ours/theirs diff.
  let refined : Array[Diff3Section] = []
  for section in sections {
    match section {
      Diff3Section::Clean(_) => refined.push(section)
      Diff3Section::Conflict(ours~, base~, theirs~) => {
        let changes = extract_changes(myers_diff(ours, theirs))
        if changes.length() == 0 {
          refined.push(Diff3Section::Clean(ours))
          continue
        }
        ignore(base)
        let mut po = 0
        for c in changes {
          if po < c.base_start {
            refined.push(Diff3Section::Clean(slice_lines(ours, po, c.base_start)))
          }
          refined.push(
            Diff3Section::Conflict(
              ours=slice_lines(ours, c.base_start, c.base_end),
              base=[],
              theirs=slice_lines(theirs, c.new_start, c.new_end),
            ),
          )
          po = c.base_end
        }
        if po < ours.length() {
          refined.push(Diff3Section::Clean(slice_lines(ours, po, ours.length())))
        }
      }
    }
  }
  // 2. Merge consecutive clean sections, then join conflicts whose gap is
  //    at most 3 lines.
  let flat : Array[Diff3Section] = []
  for section in refined {
    match (section, flat.last()) {
      (Diff3Section::Clean(a), Some(Diff3Section::Clean(prev))) => {
        ignore(flat.pop())
        let joined = prev.copy()
        joined.append(a)
        flat.push(Diff3Section::Clean(joined))
      }
      _ => flat.push(section)
    }
  }
  let out : Array[Diff3Section] = []
  let mut i = 0
  while i < flat.length() {
    match flat[i] {
      Diff3Section::Conflict(ours~, base~, theirs~) => {
        let o = ours.copy()
        let t = theirs.copy()
        let b = base.copy()
        let mut j = i + 1
        while j + 1 < flat.length() {
          match (flat[j], flat[j + 1]) {
            (Diff3Section::Clean(gap), Diff3Section::Conflict(ours=o2, base=b2, theirs=t2)) if gap.length() <=
              3 => {
              o.append(gap)
              o.append(o2)
              t.append(gap)
              t.append(t2)
              b.append(b2)
              j = j + 2
            }
            _ => break
          }
        }
        out.push(Diff3Section::Conflict(ours=o, base=b, theirs=t))
        i = j
      }
      section => {
        out.push(section)
        i = i + 1
      }
    }
  }
  out
}
