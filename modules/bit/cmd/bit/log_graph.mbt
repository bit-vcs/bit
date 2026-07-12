// Graph rendering for `bit log --graph`. This is a faithful port of git's
// graph.c state machine, extracted from log.mbt to keep that file focused on
// argument parsing, history walking, and commit formatting. The renderer is
// driven by `log_emit_commit_graph` (in log.mbt), which feeds the already
// topo-ordered commit list through this state machine.

// Graph renderer state constants — a faithful port of git's `enum graph_state`
// (graph.c). The algorithm below mirrors graph.c so that `bit log --graph`
// output is byte-for-byte identical to git's for arbitrary topologies.
///|
let graph_state_padding = 0

///|
let graph_state_skip = 1

///|
let graph_state_pre_commit = 2

///|
let graph_state_commit = 3

///|
let graph_state_post_merge = 4

///|
let graph_state_collapsing = 5

///|
/// merge_chars[] from graph.c: index 0 = '/', 1 = '|', 2 = '\\'.
let graph_merge_chars : Array[Char] = ['/', '|', '\\']

///|
/// Port of git's `struct git_graph` (graph.c). Columns hold commit hexes (""
/// means an unused slot); colors are omitted since `bit log` never colorizes
/// the graph. See third_party/git/graph.c for the field documentation.
struct GitGraph {
  mut commit : String
  mut commit_is_boundary : Bool
  mut num_parents : Int
  mut width : Int
  mut expansion_row : Int
  mut state : Int
  mut prev_state : Int
  mut commit_index : Int
  mut prev_commit_index : Int
  mut merge_layout : Int
  mut edges_added : Int
  mut prev_edges_added : Int
  mut num_columns : Int
  mut num_new_columns : Int
  mut mapping_size : Int
  mut columns : Array[String]
  mut new_columns : Array[String]
  mut mapping : Array[Int]
  mut old_mapping : Array[Int]
  mut cur_parents : Array[String]
  shown : Map[String, Bool]
  first_parent_only : Bool
  // --graph-lane-limit=<n>: cap the number of visible lanes; lanes at or
  // beyond this index are replaced with a "~" truncation mark. 0 (or any
  // value <= 0) means no limit. Mirrors git's revs->graph_max_lanes.
  graph_max_lanes : Int
}

///|
/// Port of git's graph_needs_truncation(): true when `lane` is at or beyond
/// the configured lane limit. Values <= 0 mean no limit.
fn graph_needs_truncation(g : GitGraph, lane : Int) -> Bool {
  g.graph_max_lanes > 0 && lane >= g.graph_max_lanes
}

///|
fn GitGraph::new(
  shown : Map[String, Bool],
  first_parent_only : Bool,
  graph_max_lanes : Int,
) -> GitGraph {
  {
    commit: "",
    commit_is_boundary: false,
    num_parents: 0,
    width: 0,
    expansion_row: 0,
    state: graph_state_padding,
    prev_state: graph_state_padding,
    commit_index: 0,
    prev_commit_index: 0,
    merge_layout: 0,
    edges_added: 0,
    prev_edges_added: 0,
    num_columns: 0,
    num_new_columns: 0,
    mapping_size: 0,
    columns: [],
    new_columns: [],
    mapping: [],
    old_mapping: [],
    cur_parents: [],
    shown,
    first_parent_only,
    graph_max_lanes,
  }
}

///|
/// A parent is "interesting" (gets a graph lane drawn to it) if it is part of
/// the walk — i.e. present in the full reachable `shown` set. This mirrors git's
/// graph_is_interesting(), which keys off the revision walk rather than the `-n`
/// output limit: the walk gathers the whole history, so a merge parent just past
/// an `-n` cutoff is still interesting (its lane is kept), while a parent that
/// was never walked (missing/grafted/excluded) is not, so no phantom lane is
/// drawn. With `--first-parent`, only the first parent is ever interesting.
fn graph_interesting_parents(
  g : GitGraph,
  parents : Array[String],
) -> Array[String] {
  if parents.length() == 0 {
    return []
  }
  if g.first_parent_only {
    if g.shown.get(parents[0]).unwrap_or(false) {
      return [parents[0]]
    }
    return []
  }
  let res : Array[String] = []
  for p in parents {
    if g.shown.get(p).unwrap_or(false) {
      res.push(p)
    }
  }
  res
}

///|
fn graph_update_state(g : GitGraph, s : Int) -> Unit {
  g.prev_state = g.state
  g.state = s
}

///|
fn graph_ensure_capacity(g : GitGraph, n : Int) -> Unit {
  while g.columns.length() < n {
    g.columns.push("")
  }
  while g.new_columns.length() < n {
    g.new_columns.push("")
  }
  let m = 2 * n + 2
  while g.mapping.length() < m {
    g.mapping.push(-1)
  }
  while g.old_mapping.length() < m {
    g.old_mapping.push(-1)
  }
}

///|
fn graph_find_new_column_by_commit(g : GitGraph, commit : String) -> Int {
  for i in 0..<g.num_new_columns {
    if g.new_columns[i] == commit {
      return i
    }
  }
  -1
}

///|
fn graph_num_dashed_parents(g : GitGraph) -> Int {
  g.num_parents + g.merge_layout - 3
}

///|
fn graph_num_expansion_rows(g : GitGraph) -> Int {
  graph_num_dashed_parents(g) * 2
}

///|
fn graph_needs_pre_commit_line(g : GitGraph) -> Bool {
  g.num_parents >= 3 &&
  g.commit_index < g.num_columns - 1 &&
  g.expansion_row < graph_num_expansion_rows(g)
}

///|
fn graph_is_mapping_correct(g : GitGraph) -> Bool {
  for i in 0..<g.mapping_size {
    let target = g.mapping[i]
    if target < 0 {
      continue
    }
    if target == i / 2 {
      continue
    }
    return false
  }
  true
}

///|
/// Port of git's graph_insert_into_new_columns().
fn graph_insert_into_new_columns(
  g : GitGraph,
  commit : String,
  idx : Int,
) -> Unit {
  let mut i = graph_find_new_column_by_commit(g, commit)
  let mut mapping_idx = 0
  if i < 0 {
    i = g.num_new_columns
    g.new_columns[i] = commit
    g.num_new_columns += 1
  }
  if g.num_parents > 1 && idx > -1 && g.merge_layout == -1 {
    let dist = idx - i
    let shift = if dist > 1 { 2 * dist - 3 } else { 1 }
    g.merge_layout = if dist > 0 { 0 } else { 1 }
    g.edges_added = g.num_parents + g.merge_layout - 2
    mapping_idx = g.width + (g.merge_layout - 1) * shift
    g.width += 2 * g.merge_layout
  } else if g.edges_added > 0 && g.width >= 2 && i == g.mapping[g.width - 2] {
    mapping_idx = g.width - 2
    g.edges_added = -1
  } else {
    mapping_idx = g.width
    g.width += 2
  }
  g.mapping[mapping_idx] = i
}

///|
/// Port of git's graph_update_columns().
fn graph_update_columns(g : GitGraph) -> Unit {
  let tmp = g.columns
  g.columns = g.new_columns
  g.new_columns = tmp
  g.num_columns = g.num_new_columns
  g.num_new_columns = 0
  let max_new_columns = g.num_columns + g.num_parents
  graph_ensure_capacity(g, max_new_columns)
  g.mapping_size = 2 * max_new_columns
  for i in 0..<g.mapping_size {
    g.mapping[i] = -1
  }
  g.width = 0
  g.prev_edges_added = g.edges_added
  g.edges_added = 0
  let mut seen_this = false
  let mut i = 0
  while i <= g.num_columns {
    let col_commit = if i == g.num_columns {
      if seen_this {
        break
      }
      g.commit
    } else {
      g.columns[i]
    }
    if col_commit == g.commit {
      seen_this = true
      g.commit_index = i
      g.merge_layout = -1
      for p in g.cur_parents {
        graph_insert_into_new_columns(g, p, i)
      }
      if g.num_parents == 0 {
        g.width += 2
      }
    } else {
      graph_insert_into_new_columns(g, col_commit, -1)
    }
    i += 1
  }
  // If graph_max_lanes is set, cap the width: "| " per lane plus the "~ "
  // truncation mark. Allow commits from merges to align to the merged lane.
  if g.graph_max_lanes > 0 {
    let max_width = g.graph_max_lanes * 2 + 2
    if g.width > max_width {
      g.width = max_width
    }
  }
  while g.mapping_size > 1 && g.mapping[g.mapping_size - 1] < 0 {
    g.mapping_size -= 1
  }
}

///|
/// Port of git's graph_update(): advance the graph to the next commit.
fn graph_update(
  g : GitGraph,
  commit_hex : String,
  is_boundary : Bool,
  parents : Array[String],
) -> Unit {
  g.commit = commit_hex
  g.commit_is_boundary = is_boundary
  g.cur_parents = graph_interesting_parents(g, parents)
  g.num_parents = g.cur_parents.length()
  g.prev_commit_index = g.commit_index
  graph_update_columns(g)
  g.expansion_row = 0
  if g.state != graph_state_padding {
    g.state = graph_state_skip
  } else if graph_needs_pre_commit_line(g) {
    g.state = graph_state_pre_commit
  } else {
    g.state = graph_state_commit
  }
}

///|
fn graph_pad_horizontally(g : GitGraph, line : Array[Char]) -> Unit {
  while line.length() < g.width {
    line.push(' ')
  }
}

///|
fn graph_chars_to_string(line : Array[Char]) -> String {
  let sb = StringBuilder::new()
  for c in line {
    sb.write_char(c)
  }
  sb.to_string()
}

///|
fn graph_output_padding_line(g : GitGraph, line : Array[Char]) -> Unit {
  let mut i = 0
  while i < g.num_new_columns {
    if graph_needs_truncation(g, i) {
      line.push('~')
      line.push(' ')
      break
    }
    line.push('|')
    line.push(' ')
    i += 1
  }
}

///|
fn graph_output_skip_line(g : GitGraph, line : Array[Char]) -> Unit {
  line.push('.')
  line.push('.')
  line.push('.')
  if graph_needs_pre_commit_line(g) {
    graph_update_state(g, graph_state_pre_commit)
  } else {
    graph_update_state(g, graph_state_commit)
  }
}

///|
fn graph_output_pre_commit_line(g : GitGraph, line : Array[Char]) -> Unit {
  let mut seen_this = false
  let mut i = 0
  while i < g.num_columns {
    if g.columns[i] == g.commit {
      seen_this = true
      line.push('|')
      for _ in 0..<g.expansion_row {
        line.push(' ')
      }
    } else if seen_this && graph_needs_truncation(g, i) {
      line.push('~')
      line.push(' ')
      break
    } else if seen_this && g.expansion_row == 0 {
      if g.prev_state == graph_state_post_merge && g.prev_commit_index < i {
        line.push('\\')
      } else {
        line.push('|')
      }
    } else if seen_this && g.expansion_row > 0 {
      line.push('\\')
    } else {
      line.push('|')
    }
    line.push(' ')
    i += 1
  }
  g.expansion_row += 1
  if !graph_needs_pre_commit_line(g) {
    graph_update_state(g, graph_state_commit)
  }
}

///|
fn graph_output_commit_char(g : GitGraph, line : Array[Char]) -> Unit {
  if g.commit_is_boundary {
    line.push('o')
  } else {
    line.push('*')
  }
}

///|
/// Port of git's graph_draw_octopus_merge().
fn graph_draw_octopus_merge(g : GitGraph, line : Array[Char]) -> Unit {
  let dashed = graph_num_dashed_parents(g)
  let mut i = 0
  while i < dashed {
    line.push('-')
    // Commit is at commit_index; each iteration moves one lane to the right.
    if graph_needs_truncation(g, g.commit_index + 1 + i) {
      line.push('~')
      line.push(' ')
      break
    }
    line.push(if i == dashed - 1 { '.' } else { '-' })
    i += 1
  }
}

///|
/// Port of git's graph_output_commit_line().
fn graph_output_commit_line(g : GitGraph, line : Array[Char]) -> Unit {
  let mut seen_this = false
  let mut i = 0
  while i <= g.num_columns {
    let col_commit = if i == g.num_columns {
      if seen_this {
        break
      }
      g.commit
    } else {
      g.columns[i]
    }
    if col_commit == g.commit {
      seen_this = true
      graph_output_commit_char(g, line)
      if graph_needs_truncation(g, i) {
        line.push(' ')
        break
      }
      if g.num_parents > 2 {
        graph_draw_octopus_merge(g, line)
      }
    } else if graph_needs_truncation(g, i) {
      line.push('~')
      line.push(' ')
      seen_this = true
      break
    } else if seen_this && g.edges_added > 1 {
      line.push('\\')
    } else if seen_this && g.edges_added == 1 {
      if g.prev_state == graph_state_post_merge &&
        g.prev_edges_added > 0 &&
        g.prev_commit_index < i {
        line.push('\\')
      } else {
        line.push('|')
      }
    } else if g.prev_state == graph_state_collapsing &&
      g.old_mapping[2 * i + 1] == i &&
      g.mapping[2 * i] < i {
      line.push('/')
    } else {
      line.push('|')
    }
    line.push(' ')
    i += 1
  }
  if g.num_parents > 1 {
    // If the commit is over the truncation limit but its first parent is on a
    // visible lane, we still draw the (truncated) merge lane. If both commit
    // and first parent are truncated, no merge lane is needed.
    if !graph_needs_truncation(g, g.commit_index) {
      graph_update_state(g, graph_state_post_merge)
    } else {
      let lane = graph_find_new_column_by_commit(g, g.cur_parents[0])
      if !graph_needs_truncation(g, lane) {
        graph_update_state(g, graph_state_post_merge)
      } else if graph_is_mapping_correct(g) {
        graph_update_state(g, graph_state_padding)
      } else {
        graph_update_state(g, graph_state_collapsing)
      }
    }
  } else if graph_is_mapping_correct(g) {
    graph_update_state(g, graph_state_padding)
  } else {
    graph_update_state(g, graph_state_collapsing)
  }
}

///|
/// Port of git's graph_output_post_merge_line().
fn graph_output_post_merge_line(g : GitGraph, line : Array[Char]) -> Unit {
  let mut seen_this = false
  let first_parent_hex = g.cur_parents[0]
  let mut parent_col_set = false
  let mut i = 0
  while i <= g.num_columns {
    let col_commit = if i == g.num_columns {
      if seen_this {
        break
      }
      g.commit
    } else {
      g.columns[i]
    }
    if col_commit == g.commit {
      seen_this = true
      let mut idx = g.merge_layout
      let mut truncated = false
      let mut j = 0
      while j < g.num_parents {
        let par_hex = g.cur_parents[j]
        let _par_column = graph_find_new_column_by_commit(g, par_hex)
        line.push(graph_merge_chars[idx])
        // j counts parents; halve it to compare with the column index i.
        // Don't truncate if there are no more lanes to print (end of lane).
        if graph_needs_truncation(g, j / 2 + i) && j / 2 + i <= g.num_columns {
          if (j + i * 2) % 2 != 0 {
            line.push(' ')
          }
          line.push('~')
          line.push(' ')
          truncated = true
          break
        }
        if idx == 2 {
          // Check if the next lane needs truncation to avoid doubled padding.
          if graph_needs_truncation(g, (j + 1) / 2 + i) && j < g.num_parents - 1 {
            line.push('~')
            line.push(' ')
            truncated = true
            break
          } else if g.edges_added > 0 || j < g.num_parents - 1 {
            line.push(' ')
          }
        } else {
          idx += 1
        }
        j += 1
      }
      if truncated {
        break
      }
      if g.edges_added == 0 {
        line.push(' ')
      }
    } else if graph_needs_truncation(g, i) {
      line.push('~')
      line.push(' ')
      break
    } else if seen_this {
      if g.edges_added > 0 {
        line.push('\\')
      } else {
        line.push('|')
      }
      // If it's between two lanes and the next would be truncated, don't pad.
      if !graph_needs_truncation(g, i + 1) {
        line.push(' ')
      }
    } else {
      line.push('|')
      if g.merge_layout != 0 || i != g.commit_index - 1 {
        if parent_col_set {
          line.push('_')
        } else {
          line.push(' ')
        }
      }
    }
    if col_commit == first_parent_hex {
      parent_col_set = true
    }
    i += 1
  }
  if graph_is_mapping_correct(g) {
    graph_update_state(g, graph_state_padding)
  } else {
    graph_update_state(g, graph_state_collapsing)
  }
}

///|
/// Port of git's graph_output_collapsing_line().
fn graph_output_collapsing_line(g : GitGraph, line : Array[Char]) -> Unit {
  let mut used_horizontal = false
  let mut horizontal_edge = -1
  let mut horizontal_edge_target = -1
  let tmp = g.mapping
  g.mapping = g.old_mapping
  g.old_mapping = tmp
  for i in 0..<g.mapping_size {
    g.mapping[i] = -1
  }
  for i in 0..<g.mapping_size {
    let target = g.old_mapping[i]
    if target < 0 {
      continue
    }
    if target * 2 == i {
      g.mapping[i] = target
    } else if g.mapping[i - 1] < 0 {
      g.mapping[i - 1] = target
      if horizontal_edge == -1 {
        horizontal_edge = i
        horizontal_edge_target = target
        let mut j = target * 2 + 3
        while j < i - 2 {
          g.mapping[j] = target
          j += 2
        }
      }
    } else if g.mapping[i - 1] == target {
      // Already merged into the branch line to our left.
      ()
    } else {
      g.mapping[i - 2] = target
      if horizontal_edge == -1 {
        horizontal_edge_target = target
        horizontal_edge = i - 1
        let mut j = target * 2 + 3
        while j < i - 2 {
          g.mapping[j] = target
          j += 2
        }
      }
    }
  }
  for i in 0..<g.mapping_size {
    g.old_mapping[i] = g.mapping[i]
  }
  if g.mapping[g.mapping_size - 1] < 0 {
    g.mapping_size -= 1
  }
  let mut truncated = false
  for i in 0..<g.mapping_size {
    let target = g.mapping[i]
    if !truncated && graph_needs_truncation(g, i / 2) {
      line.push('~')
      line.push(' ')
      truncated = true
    }
    if target < 0 {
      if !truncated {
        line.push(' ')
      }
    } else if target * 2 == i {
      if !truncated {
        line.push('|')
      }
    } else if target == horizontal_edge_target && i != horizontal_edge - 1 {
      if i != target * 2 + 3 {
        g.mapping[i] = -1
      }
      used_horizontal = true
      if !truncated {
        line.push('_')
      }
    } else {
      if used_horizontal && i < horizontal_edge {
        g.mapping[i] = -1
      }
      if !truncated {
        line.push('/')
      }
    }
  }
  if graph_is_mapping_correct(g) {
    graph_update_state(g, graph_state_padding)
  }
}

///|
/// Port of git's graph_next_line(): emit one graph line for the current state.
/// Returns the padded line and whether it was the commit (`*`) line.
fn graph_next_line(g : GitGraph) -> (String, Bool) {
  let line : Array[Char] = []
  let mut shown = false
  if g.state == graph_state_padding {
    graph_output_padding_line(g, line)
  } else if g.state == graph_state_skip {
    graph_output_skip_line(g, line)
  } else if g.state == graph_state_pre_commit {
    graph_output_pre_commit_line(g, line)
  } else if g.state == graph_state_commit {
    graph_output_commit_line(g, line)
    shown = true
  } else if g.state == graph_state_post_merge {
    graph_output_post_merge_line(g, line)
  } else {
    graph_output_collapsing_line(g, line)
  }
  graph_pad_horizontally(g, line)
  (graph_chars_to_string(line), shown)
}

///|
/// Port of git's graph_padding_line(): the inter-entry separator row. When the
/// current state is GRAPH_COMMIT this draws the special padding that keeps merge
/// columns aligned; otherwise it falls through to graph_next_line().
fn graph_padding_line(g : GitGraph) -> String {
  if g.state != graph_state_commit {
    return graph_next_line(g).0
  }
  let line : Array[Char] = []
  let mut i = 0
  while i < g.num_columns {
    if graph_needs_truncation(g, i) {
      line.push('~')
      line.push(' ')
      break
    }
    line.push('|')
    if g.columns[i] == g.commit && g.num_parents > 2 {
      let len = (g.num_parents - 2) * 2
      for _ in 0..<len {
        line.push(' ')
      }
    } else {
      line.push(' ')
    }
    i += 1
  }
  graph_pad_horizontally(g, line)
  g.prev_state = graph_state_padding
  graph_chars_to_string(line)
}
