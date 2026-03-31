///|
test "component impl: clone target helpers choose default explicit and missing refs" {
  let refs : Array[(@bit.ObjectId, String)] = [
    (@bit.ObjectId::from_hex(component_impl_fixture_commit), "refs/heads/main"),
    (
      @bit.ObjectId::from_hex("1111111111111111111111111111111111111111"),
      "refs/heads/feature",
    ),
  ]
  let symrefs : Map[String, String] = { "HEAD": "refs/heads/main" }

  inspect(
    match net_select_clone_target(refs, symrefs, "") {
      Some((refname, _)) => Some(refname)
      None => None
    },
    content="Some(\"refs/heads/main\")",
  )
  inspect(
    match net_select_clone_target(refs, symrefs, "feature") {
      Some((refname, _)) => Some(refname)
      None => None
    },
    content="Some(\"refs/heads/feature\")",
  )
  inspect(
    match net_select_clone_target(refs, symrefs, "missing") {
      Some((refname, _)) => Some(refname)
      None => None
    },
    content="None",
  )
}
