///|
test "reverse_patch swaps add/delete lines" {
  let patch = "--- a/file.txt\n+++ b/file.txt\n@@ -1,3 +1,3 @@\n context\n-old line\n+new line\n context\n"
  let reversed = @apply.reverse_patch(patch)
  assert_true(reversed.contains("+++ b/file.txt"))
  assert_true(reversed.contains("--- a/file.txt"))
  assert_true(reversed.contains("+old line"))
  assert_true(reversed.contains("-new line"))
  assert_true(reversed.contains(" context"))
}

///|
test "reverse_patch empty input" {
  let result = @apply.reverse_patch("")
  assert_eq(result, "")
}

///|
test "parse_patches simple diff" {
  let patch =
    #|diff --git a/foo.txt b/foo.txt
    #|--- a/foo.txt
    #|+++ b/foo.txt
    #|@@ -1,2 +1,3 @@
    #| hello
    #|-world
    #|+world!
    #|+extra
  let patches = @apply.parse_patches(patch)
  assert_eq(patches.length(), 1)
  assert_eq(patches[0].display_name, "foo.txt")
  assert_eq(patches[0].additions, 2)
  assert_eq(patches[0].deletions, 1)
  assert_false(patches[0].is_new)
  assert_false(patches[0].is_delete)
}

///|
test "parse_patches new file" {
  let patch =
    #|diff --git a/new.txt b/new.txt
    #|new file mode 100644
    #|--- /dev/null
    #|+++ b/new.txt
    #|@@ -0,0 +1 @@
    #|+hello
  let patches = @apply.parse_patches(patch)
  assert_eq(patches.length(), 1)
  assert_true(patches[0].is_new)
  assert_eq(patches[0].new_mode, "100644")
  assert_eq(patches[0].additions, 1)
}

///|
test "parse_patches rename" {
  let patch =
    #|diff --git a/old.txt b/new.txt
    #|similarity index 95%
    #|rename from old.txt
    #|rename to new.txt
  let patches = @apply.parse_patches(patch)
  assert_eq(patches.length(), 1)
  assert_true(patches[0].is_rename)
  assert_eq(patches[0].old_name, "old.txt")
  assert_eq(patches[0].new_name, "new.txt")
  assert_eq(patches[0].similarity_index, 95)
}

///|
test "parse_diff_git_header" {
  let (old_name, new_name) = @apply.parse_diff_git_header(
    "a/src/main.mbt b/src/main.mbt",
  )
  assert_eq(old_name, "src/main.mbt")
  assert_eq(new_name, "src/main.mbt")
}

///|
test "parse_pct" {
  assert_eq(@apply.parse_pct("95%"), 95)
  assert_eq(@apply.parse_pct("100%"), 100)
  assert_eq(@apply.parse_pct("0%"), 0)
}
