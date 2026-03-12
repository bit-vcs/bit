///|
test "grep pattern: fixed treats dot literally" {
  assert_false(
    grep_patterns_match_message("(1|2)", ["..."], GrepPatternType::Fixed, false),
  )
}

///|
test "grep pattern: basic treats dot as wildcard" {
  assert_true(
    grep_patterns_match_message("(1|2)", ["..."], GrepPatternType::Basic, false),
  )
}

///|
test "grep pattern: ignore-case works for fixed mode" {
  assert_true(
    grep_patterns_match_message("Second", ["sec"], GrepPatternType::Fixed, true),
  )
}

///|
test "grep pattern: basic treats escaped dot literally" {
  assert_true(
    grep_message_matches_pattern("a.c", "a\\.c", GrepPatternType::Basic, false),
  )
  assert_false(
    grep_message_matches_pattern("abc", "a\\.c", GrepPatternType::Basic, false),
  )
}

///|
test "grep pattern: basic treats dollar as end anchor" {
  assert_eq(
    grep_first_match_span("foo mmap", "mmap$", GrepPatternType::Basic, false),
    Some({ start_column: 5, end_column: 8 }),
  )
  assert_eq(
    grep_first_match_span(
      "foo mmap baz",
      "mmap$",
      GrepPatternType::Basic,
      false,
    ),
    None,
  )
}

///|
test "grep pattern: basic treats star as repetition" {
  assert_true(
    grep_message_matches_pattern("a+bc", "a+b*c", GrepPatternType::Basic, false),
  )
  assert_false(
    grep_message_matches_pattern(
      "a+b*c",
      "a+b*c",
      GrepPatternType::Basic,
      false,
    ),
  )
}

///|
test "grep pattern: extended treats plus and star as repetition" {
  assert_true(
    grep_message_matches_pattern(
      "abc",
      "a+b*c",
      GrepPatternType::Extended,
      false,
    ),
  )
  assert_false(
    grep_message_matches_pattern(
      "a+b*c",
      "a+b*c",
      GrepPatternType::Extended,
      false,
    ),
  )
}

///|
test "grep pattern: extended treats bracket expression as character class" {
  assert_true(
    grep_message_matches_pattern("d", "[\\d]", GrepPatternType::Extended, false),
  )
}

///|
test "grep pattern: resolve prefers cli then override then repo config" {
  let fs = @bit.TestFs::new()
  @bitlib.init_repo(fs, "/repo")
  fs.write_string("/repo/.git/config", "[grep]\n\tpatternType = perl\n")

  assert_eq(
    resolve_grep_pattern_type(
      fs,
      "/repo/.git",
      Some(GrepPatternType::Extended),
      Some("fixed"),
    ),
    GrepPatternType::Extended,
  )
  assert_eq(
    resolve_grep_pattern_type(fs, "/repo/.git", None, Some("fixed")),
    GrepPatternType::Fixed,
  )
  assert_eq(
    resolve_grep_pattern_type(fs, "/repo/.git", None, None),
    GrepPatternType::Perl,
  )
}

///|
test "grep pattern: extract_commit_message_from_raw returns message body" {
  let raw = @utf8.encode(
    "tree 123456\nparent 789abc\nauthor T <t@example.com> 0 +0000\n\nsubject\nbody\n",
  )
  assert_eq(extract_commit_message_from_raw(raw), "subject\nbody\n")
}

///|
test "grep pattern: validate rejects unmatched group syntax" {
  let result : Result[Unit, Error] = try? validate_grep_patterns(
    ["("],
    GrepPatternType::Basic,
  )
  match result {
    Ok(_) => fail("expected invalid regex error")
    Err(err) =>
      inspect(
        err.to_string().contains("invalid regular expression"),
        content="true",
      )
  }
}

///|
test "grep pattern: first span returns earliest matching column across patterns" {
  inspect(
    grep_patterns_first_match_span(
      "foo mmap bar",
      ["bar", "mmap"],
      GrepPatternType::Fixed,
      false,
    ),
    content="Some({start_column: 5, end_column: 8})",
  )
}

///|
test "grep pattern: word regexp excludes embedded underscore matches" {
  assert_eq(
    grep_first_match_span(
      "foo_mmap bar mmap",
      "mmap",
      GrepPatternType::Fixed,
      false,
      word_regexp=true,
    ),
    Some({ start_column: 14, end_column: 17 }),
  )
}

///|
test "grep pattern: collect match spans returns repeated fixed matches" {
  inspect(
    grep_collect_expr_match_spans(
      "foo mmap bar mmap",
      GrepExpr::Pattern("mmap"),
      GrepPatternType::Fixed,
      false,
    ),
    content=(
      #|[{start_column: 5, end_column: 8}, {start_column: 14, end_column: 17}]
    ),
  )
}

///|
test "grep pattern: collect match spans stays non-overlapping" {
  inspect(
    grep_collect_expr_match_spans(
      "aaaa",
      GrepExpr::Pattern("aa"),
      GrepPatternType::Fixed,
      false,
    ),
    content=(
      #|[{start_column: 1, end_column: 2}, {start_column: 3, end_column: 4}]
    ),
  )
}

///|
test "grep pattern: parse boolean expression respects grouping" {
  let expr = parse_grep_expr([
    GrepExprToken::Not,
    GrepExprToken::LParen,
    GrepExprToken::Not,
    GrepExprToken::Pattern("foo"),
    GrepExprToken::Or,
    GrepExprToken::Not,
    GrepExprToken::Pattern("baz"),
    GrepExprToken::RParen,
  ])
  match expr {
    GrepExpr::Not(inner) =>
      match inner {
        GrepExpr::Or(lhs, rhs) => {
          assert_true(lhs is GrepExpr::Not(_))
          assert_true(rhs is GrepExpr::Not(_))
        }
        _ => fail("expected inner or expression")
      }
    _ => fail("expected top-level not expression")
  }
}

///|
test "grep pattern: boolean expression keeps earliest positive span" {
  let expr = parse_grep_expr([
    GrepExprToken::Not,
    GrepExprToken::Pattern("_"),
    GrepExprToken::And,
    GrepExprToken::Not,
    GrepExprToken::Pattern("ll"),
  ])
  assert_eq(
    grep_eval_expr("Hello_world", expr, GrepPatternType::Fixed, false),
    { matched: false, span: Some({ start_column: 3, end_column: 4 }) },
  )
  assert_eq(
    grep_eval_expr("HeLLo_world", expr, GrepPatternType::Fixed, false),
    { matched: false, span: Some({ start_column: 6, end_column: 6 }) },
  )
}
