///| Benchmarks for gitignore pattern matching

///|
test "bench match_glob simple" (b : @bench.T) {
  b.bench(fn() {
    b.keep(@ignore.match_glob("*.txt", "some/deep/path/to/file.txt"))
  })
}

///|
test "bench match_glob no match" (b : @bench.T) {
  b.bench(fn() {
    b.keep(@ignore.match_glob("*.txt", "some/deep/path/to/file.rs"))
  })
}

///|
test "bench match_glob double star" (b : @bench.T) {
  b.bench(fn() {
    b.keep(@ignore.match_glob("**/*.test.js", "src/components/Button.test.js"))
  })
}

///|
test "bench parse gitignore 20 rules" (b : @bench.T) {
  let content =
    #|# Node
    #|node_modules/
    #|dist/
    #|*.log
    #|!important.log
    #|
    #|# Build
    #|/build
    #|/out
    #|*.o
    #|*.a
    #|*.so
    #|
    #|# Editor
    #|.vscode/
    #|.idea/
    #|*.swp
    #|*.swo
    #|*~
    #|
    #|# OS
    #|.DS_Store
    #|Thumbs.db
    #|
  b.bench(fn() { b.keep(@ignore.parse(content, "")) })
}

///|
test "bench is_ignored 20 rules not ignored" (b : @bench.T) {
  let content =
    #|node_modules/
    #|dist/
    #|*.log
    #|!important.log
    #|/build
    #|/out
    #|*.o
    #|*.a
    #|*.so
    #|.vscode/
    #|.idea/
    #|*.swp
    #|*.swo
    #|*~
    #|.DS_Store
    #|Thumbs.db
    #|__pycache__/
    #|*.pyc
    #|.env
    #|coverage/
    #|
  let m = @ignore.Matcher::new()
  m.add_rules("", content)
  b.bench(fn() { b.keep(m.is_ignored("src/components/Button.tsx", false)) })
}

///|
test "bench is_ignored 20 rules ignored" (b : @bench.T) {
  let content =
    #|node_modules/
    #|dist/
    #|*.log
    #|!important.log
    #|/build
    #|/out
    #|*.o
    #|*.a
    #|*.so
    #|.vscode/
    #|.idea/
    #|*.swp
    #|*.swo
    #|*~
    #|.DS_Store
    #|Thumbs.db
    #|__pycache__/
    #|*.pyc
    #|.env
    #|coverage/
    #|
  let m = @ignore.Matcher::new()
  m.add_rules("", content)
  b.bench(fn() {
    b.keep(m.is_ignored("node_modules/express/lib/index.js", false))
  })
}

///|
test "bench is_ignored nested bases" (b : @bench.T) {
  let m = @ignore.Matcher::new()
  m.add_rules("", "*.log\n*.tmp\n/build\n")
  m.add_rules("src", "*.generated.*\n!keep.generated.ts\n")
  m.add_rules("src/vendor", "*\n!README.md\n")
  b.bench(fn() { b.keep(m.is_ignored("src/vendor/lib/deep/file.js", false)) })
}

///|
test "bench 1000 paths against 20 rules" (b : @bench.T) {
  let content =
    #|node_modules/
    #|dist/
    #|*.log
    #|!important.log
    #|/build
    #|*.o
    #|*.a
    #|*.so
    #|.vscode/
    #|.idea/
    #|*.swp
    #|*.swo
    #|*~
    #|.DS_Store
    #|Thumbs.db
    #|__pycache__/
    #|*.pyc
    #|.env
    #|coverage/
    #|*.min.js
    #|
  let m = @ignore.Matcher::new()
  m.add_rules("", content)
  let paths : Array[String] = []
  for i in 0..<1000 {
    let dir = match i % 5 {
      0 => "src"
      1 => "lib"
      2 => "test"
      3 => "docs"
      _ => "pkg"
    }
    let ext = match i % 4 {
      0 => ".ts"
      1 => ".js"
      2 => ".log"
      _ => ".rs"
    }
    paths.push(dir + "/file" + i.to_string() + ext)
  }
  b.bench(fn() {
    let mut count = 0
    for p in paths {
      if m.is_ignored(p, false) {
        count += 1
      }
    }
    b.keep(count)
  })
}
