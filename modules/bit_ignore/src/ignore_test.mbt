///|
/// Tests for gitignore pattern matching
test "parse simple patterns" {
  let rules = @bit_ignore.parse("*.txt\nnode_modules/\n", "")
  assert_eq(rules.length(), 2)
  assert_eq(rules[0].pattern, "*.txt")
  assert_eq(rules[0].dir_only, false)
  assert_eq(rules[1].pattern, "node_modules")
  assert_eq(rules[1].dir_only, true)
}

///|
test "parse negation" {
  let rules = @bit_ignore.parse("*.log\n!important.log\n", "")
  assert_eq(rules.length(), 2)
  assert_eq(rules[0].negated, false)
  assert_eq(rules[1].negated, true)
  assert_eq(rules[1].pattern, "important.log")
}

///|
test "parse anchored patterns" {
  let rules = @bit_ignore.parse("/build\n*.o\n", "")
  assert_eq(rules.length(), 2)
  assert_eq(rules[0].anchored, true)
  assert_eq(rules[0].pattern, "build")
  assert_eq(rules[1].anchored, false)
}

///|
test "parse comments and empty lines" {
  let rules = @bit_ignore.parse("# comment\n\n*.txt\n  \n", "")
  assert_eq(rules.length(), 1)
  assert_eq(rules[0].pattern, "*.txt")
}

///|
test "parse escaped characters" {
  let rules = @bit_ignore.parse("\\!important\n\\#hash\n", "")
  assert_eq(rules.length(), 2)
  assert_eq(rules[0].pattern, "!important")
  assert_eq(rules[0].negated, false)
  assert_eq(rules[1].pattern, "#hash")
}

///|
test "match_glob simple" {
  assert_true(@bit_ignore.match_glob("*.txt", "file.txt"))
  assert_true(@bit_ignore.match_glob("*.txt", "a.txt"))
  assert_false(@bit_ignore.match_glob("*.txt", "file.log"))
  assert_false(@bit_ignore.match_glob("*.txt", "txt"))
}

///|
test "match_glob question mark" {
  assert_true(@bit_ignore.match_glob("file?.txt", "file1.txt"))
  assert_true(@bit_ignore.match_glob("file?.txt", "fileA.txt"))
  assert_false(@bit_ignore.match_glob("file?.txt", "file10.txt"))
  assert_false(@bit_ignore.match_glob("file?.txt", "file.txt"))
}

///|
test "match_glob multiple wildcards" {
  assert_true(@bit_ignore.match_glob("*.min.*", "app.min.js"))
  assert_true(@bit_ignore.match_glob("*.min.*", "lib.min.css"))
  assert_false(@bit_ignore.match_glob("*.min.*", "app.js"))
}

///|
test "matcher basic" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "*.log\nnode_modules/\n")
  assert_true(m.is_ignored("debug.log", false))
  assert_true(m.is_ignored("logs/error.log", false))
  assert_true(m.is_ignored("node_modules", true))
  assert_true(m.is_ignored("node_modules/pkg/index.js", false))
  assert_false(m.is_ignored("src/main.js", false))
}

///|
test "matcher negation" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "*.log\n!important.log\n")
  assert_true(m.is_ignored("debug.log", false))
  assert_false(m.is_ignored("important.log", false))
}

///|
test "matcher anchored pattern" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "/build\n")
  assert_true(m.is_ignored("build", true))
  assert_false(m.is_ignored("src/build", true))
}

///|
test "matcher with base" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("src", "*.bak\n")
  assert_true(m.is_ignored("src/file.bak", false))
  assert_false(m.is_ignored("file.bak", false))
  assert_false(m.is_ignored("other/file.bak", false))
}

///|
test "matcher double star" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "**/test\n")
  assert_true(m.is_ignored("test", true))
  assert_true(m.is_ignored("src/test", true))
  assert_true(m.is_ignored("src/pkg/test", true))
}

///|
test "matcher truncate" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "*.txt\n")
  let len = m.len()
  m.add_rules("src", "*.bak\n")
  assert_true(m.is_ignored("src/file.bak", false))
  m.truncate(len)
  assert_false(m.is_ignored("src/file.bak", false))
  assert_true(m.is_ignored("file.txt", false))
}

///|
test "git-aware glob filter" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "*.log\n/dist/\nbuild/\n")
  m.add_rules("src", "*.generated.*\n!keep.generated.ts\n")
  let files : Array[String] = [
    "src/app.ts", "src/data.generated.js", "src/keep.generated.ts", "dist/bundle.js",
    "lib/build/out.o", "server.log",
  ]
  let visible = files.filter(fn(p) { !m.is_ignored(p, false) })
  assert_eq(visible.length(), 2)
  assert_true(visible.contains("src/app.ts"))
  assert_true(visible.contains("src/keep.generated.ts"))
}

///|
test "directory traversal backtracking" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "*.tmp\n")
  let saved = m.len()
  m.add_rules("src", "*.bak\n")
  assert_true(m.is_ignored("src/file.bak", false))
  m.truncate(saved)
  assert_false(m.is_ignored("src/file.bak", false))
  assert_true(m.is_ignored("any/path/file.tmp", false))
}

///|
test "character classes and escaped wildcards (issue #208)" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "[ab].txt\nfile\\?.txt\n")
  assert_true(m.is_ignored("a.txt", false))
  assert_true(m.is_ignored("b.txt", false))
  assert_false(m.is_ignored("c.txt", false))
  assert_true(m.is_ignored("file?.txt", false))
  assert_false(m.is_ignored("filex.txt", false))
}

///|
test "glob syntax matches git check-ignore" {
  // Each (pattern, path, expected) was checked with
  // `git check-ignore --no-index`.
  let cases : Array[(String, String, Bool)] = [
    ("log[0-9]", "log5", true),
    ("log[0-9]", "logx", false),
    ("[!0-9]num", "anum", true),
    ("[!0-9]num", "5num", false),
    ("[^z]caret", "acaret", true),
    ("[^z]caret", "zcaret", false),
    ("r[a-c]", "rb", true),
    ("r[a-c]", "rd", false),
    ("x[[:digit:]]y", "x5y", true),
    ("x[[:digit:]]y", "xay", false),
    ("star\\*", "star*", true),
    ("star\\*", "starx", false),
    ("br\\[x\\]", "br[x]", true),
    ("br\\[x\\]", "bx", false),
    ("[]]rb", "]rb", true),
    ("[\\]]esc", "]esc", true),
    ("[a-]dash", "-dash", true),
    ("[a-]dash", "adash", true),
    ("[abc", "[abc", false),
    ("tail\\", "tail\\", false),
    ("tail\\", "tail", false),
    ("sp\\ ", "sp ", true),
    ("sp\\ ", "sp", false),
  ]
  for case in cases {
    let (pattern, path, expected) = case
    let m = @bit_ignore.Matcher::new()
    m.add_rules("", pattern + "\n")
    assert_eq(m.is_ignored(path, false), expected, msg="\{pattern} vs \{path}")
  }
}

///|
test "character classes in path patterns" {
  let m = @bit_ignore.Matcher::new()
  m.add_rules("", "build/[0-9]*/\ndocs/*.[mM][dD]\n")
  assert_true(m.is_ignored("build/2024/out.bin", false))
  assert_false(m.is_ignored("build/latest/out.bin", false))
  assert_true(m.is_ignored("docs/README.MD", false))
  assert_false(m.is_ignored("docs/README.txt", false))
}

///|
test "match_glob supports classes and escapes" {
  assert_true(@bit_ignore.match_glob("v[0-9].*", "v1.2"))
  assert_false(@bit_ignore.match_glob("v[0-9].*", "vx.2"))
  assert_true(@bit_ignore.match_glob("a\\*b", "a*b"))
  assert_false(@bit_ignore.match_glob("a\\*b", "axxb"))
}
