///|
test "pull: detect submodule replaced by file" {
  let from_modes : Map[String, Int] = {}
  from_modes["sub1"] = 0o160000
  let to_modes : Map[String, Int] = {}
  to_modes["sub1"] = 0o100644
  let replaced = find_submodule_replaced_with_non_submodule(
    from_modes, to_modes,
  )
  assert_eq(replaced, Some("sub1"))
}

///|
test "pull: do not flag submodule removal" {
  let from_modes : Map[String, Int] = {}
  from_modes["sub1"] = 0o160000
  let to_modes : Map[String, Int] = {}
  let replaced = find_submodule_replaced_with_non_submodule(
    from_modes, to_modes,
  )
  assert_eq(replaced, None)
}

///|
test "pull: initial head target uses current branch ref" {
  let target = resolve_initial_pull_head_target(Some("main"))
  assert_eq(target, "refs/heads/main")
}

///|
test "pull: initial head target uses detached HEAD" {
  let target = resolve_initial_pull_head_target(None)
  assert_eq(target, "HEAD")
}
