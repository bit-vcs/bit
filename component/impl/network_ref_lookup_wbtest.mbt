///|
test "component impl: network ref lookup helpers parse symrefs and find refs" {
  assert_eq(
    net_parse_symrefs_from_capabilities([
      "multi_ack", "symref=HEAD:refs/heads/main", "symref-target:refs/heads/trunk",
    ]),
    { "HEAD": "refs/heads/trunk" },
  )

  inspect(
    net_find_ref(
      [
        (
          @bit.ObjectId::from_hex(component_impl_fixture_commit),
          "refs/heads/main",
        ),
      ],
      "refs/heads/main",
    ).to_hex(),
    content=component_impl_fixture_commit,
  )
}
