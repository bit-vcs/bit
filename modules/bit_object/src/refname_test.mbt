///|
test "check_refname_format: git check-ref-format rules" {
  for
    name in [
      "refs/heads/main", "refs/heads/feature/x", "refs/tags/v1.0.0", "refs/remotes/origin/HEAD",
      "refs/heads/a.b", "refs/heads/x\"y", "refs/heads/@",
    ] {
    assert_true(@bit_object.check_refname_format(name), msg=name)
  }
  for
    name in [
      "", "@", "/refs/heads/x", "refs/heads/x/", "refs/heads/x.", ".refs/x", "refs/heads/../../x",
      "refs/heads/a..b", "refs/heads/.hidden", "refs/heads/x.lock", "refs/heads/x.lock/y",
      "refs//heads", "refs/heads/a b", "refs/heads/a\tb", "refs/heads/a\nb", "refs/heads/a~1",
      "refs/heads/a^", "refs/heads/a:b", "refs/heads/a?", "refs/heads/a*", "refs/heads/a[b",
      "refs/heads/a\\b", "refs/heads/a@{1}", "refs/heads/\u{7f}", "main",
    ] {
    assert_false(@bit_object.check_refname_format(name), msg=name)
  }
  assert_true(@bit_object.check_refname_format("main", allow_onelevel=true))
  assert_false(@bit_object.check_refname_format("..", allow_onelevel=true))
}

///|
test "is_valid_remote_refname: only HEAD and well-formed refs/ names" {
  for
    name in [
      "HEAD", "refs/heads/main", "refs/tags/v1", "refs/tags/v1^{}", "refs/pull/1/head",
    ] {
    assert_true(@bit_object.is_valid_remote_refname(name), msg=name)
  }
  for
    name in [
      "../../../../tmp/x", "refs/heads/../../../../x", "refs/heads/../../heads/main", "hooks/pre-commit",
      "capabilities^{}", "refs/heads/x\n[core]", "refs/heads/x^{}^{}", "config", "",
    ] {
    assert_false(@bit_object.is_valid_remote_refname(name), msg=name)
  }
  assert_true(@bit_object.is_valid_remote_symref_target("refs/heads/main"))
  assert_false(@bit_object.is_valid_remote_symref_target("refs/heads/../../../../x"))
  assert_false(@bit_object.is_valid_remote_symref_target("HEAD"))
}
