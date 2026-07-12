///| White-box tests for `log --graph --graph-lane-limit=<n>` (Git 2.55).
///
/// git 2.55 isn't available in this environment (git 2.53 ships here), so these
/// don't byte-compare against upstream. Instead they drive the ported graph.c
/// state machine directly and assert:
///   * the base renderer is unchanged when no limit is set (exact art),
///   * a limit that never triggers leaves output byte-identical (idempotence),
///   * a limit that does trigger caps the lane width at `n*2+2` and inserts the
///     "~" truncation mark.
/// The truncation logic itself is a faithful port of git 2.55's graph.c.

///|
/// Drive the ported graph renderer over `commits` (newest-first, each entry is
/// (hex, parents_hex)) in the oneline layout and return the pure graph-art rows
/// (each padded to the current graph width; no commit content appended).
fn gll_render_art(
  commits : Array[(String, Array[String])],
  max_lanes : Int,
) -> Array[String] {
  let shown : Map[String, Bool] = {}
  for c in commits {
    shown[c.0] = true
  }
  let g = GitGraph::new(shown, false, max_lanes)
  let lines : Array[String] = []
  for c in commits {
    let (hex, parents) = c
    graph_update(g, hex, false, parents)
    // oneline layout emits no padding row between entries.
    let mut got_commit = false
    while !got_commit {
      let (s, is_commit) = graph_next_line(g)
      lines.push(s)
      if is_commit {
        got_commit = true
      }
    }
    while g.state != graph_state_padding {
      let (s, _) = graph_next_line(g)
      lines.push(s)
    }
  }
  lines
}

///|
fn gll_any_contains_tilde(lines : Array[String]) -> Bool {
  for l in lines {
    if l.contains("~") {
      return true
    }
  }
  false
}

///|
fn gll_max_width(lines : Array[String]) -> Int {
  let mut m = 0
  for l in lines {
    if l.length() > m {
      m = l.length()
    }
  }
  m
}

///|
/// Linear history renders as one "* " lane per commit, and a limit is a no-op.
test "graph-lane-limit: linear history unaffected" {
  let commits : Array[(String, Array[String])] = [
    ("c1", ["c2"]),
    ("c2", ["c3"]),
    ("c3", []),
  ]
  let no_limit = gll_render_art(commits, 0)
  @test.assert_eq(no_limit, ["* ", "* ", "* "])
  // A single lane never reaches lane index 1, so --graph-lane-limit=1 matches.
  @test.assert_eq(gll_render_art(commits, 1), no_limit)
  @test.assert_eq(gll_render_art(commits, 5), no_limit)
}

///|
/// A limit larger than the graph's actual lane count must not change output.
test "graph-lane-limit: non-triggering limit is idempotent (merge)" {
  // M is a 2-way merge; the graph never exceeds 2 lanes.
  let commits : Array[(String, Array[String])] = [
    ("M", ["A", "B"]),
    ("A", ["C"]),
    ("B", ["C"]),
    ("C", []),
  ]
  let baseline = gll_render_art(commits, 0)
  // 2 lanes -> limit of 3 (and above) never truncates.
  @test.assert_eq(gll_render_art(commits, 3), baseline)
  @test.assert_eq(gll_render_art(commits, 9), baseline)
  // The merge really does use 2 lanes, so a "|" appears beyond the first column.
  assert_true(gll_max_width(baseline) >= 4)
  // Nothing is truncated at these limits.
  assert_true(!gll_any_contains_tilde(gll_render_art(commits, 3)))
}

///|
/// A limit that DOES trigger caps the art width at n*2+2 and inserts "~".
test "graph-lane-limit: second lane truncated with ~" {
  // A 2-way merge opens a second lane (index 1). With --graph-lane-limit=1
  // that lane is at/above the limit and must be replaced with the "~" mark.
  let commits : Array[(String, Array[String])] = [
    ("M", ["A", "B"]),
    ("A", ["C"]),
    ("B", ["C"]),
    ("C", []),
  ]
  // Unlimited: the merge genuinely uses a second lane (no "~").
  let unlimited = gll_render_art(commits, 0)
  assert_true(!gll_any_contains_tilde(unlimited))
  assert_true(gll_max_width(unlimited) >= 3)

  // Limited to 1 lane: every art row is capped at 1*2+2 = 4 columns and the
  // truncation mark appears where the second lane would have been drawn.
  let limited = gll_render_art(commits, 1)
  assert_true(gll_max_width(limited) <= 1 * 2 + 2)
  assert_true(gll_any_contains_tilde(limited))
}
