///|
test "rebase: --root requires real git fallback" {
  assert_true(rebase_requires_real_git(["--root"]))
  assert_true(rebase_requires_real_git(["--force-rebase", "--root"]))
  assert_false(rebase_requires_real_git(["--force-rebase", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["--no-force-rebase", "HEAD~1"]))
  assert_false(rebase_requires_real_git(["main"]))
}
