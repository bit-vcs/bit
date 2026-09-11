///|
fn route_of(target : String) -> String {
  match http_split_route(target) {
    Some((repo, endpoint, query)) => "\{repo}|\{endpoint}|\{query}"
    None => "<none>"
  }
}

///|
test "serve --http: a repository path may contain slashes" {
  @test.assert_eq(
    route_of("/acme/app.git/info/refs?service=git-upload-pack"),
    "/acme/app.git|/info/refs|service=git-upload-pack",
  )
  @test.assert_eq(
    route_of("/acme/app.git/git-upload-pack"),
    "/acme/app.git|/git-upload-pack|",
  )
  @test.assert_eq(
    route_of("/deep/nested/group/repo.git/git-receive-pack"),
    "/deep/nested/group/repo.git|/git-receive-pack|",
  )
}

///|
test "serve --http: a target with no known endpoint does not route" {
  @test.assert_eq(route_of("/acme/app.git"), "<none>")
  @test.assert_eq(route_of("/"), "<none>")
  @test.assert_eq(route_of("/objects/info/packs"), "<none>")
}

///|
fn resolved(root : String, repo : String) -> String {
  match http_resolve_repo(root, repo) {
    Some(path) => path
    None => "<rejected>"
  }
}

///|
test "serve --http: a repository resolves under the root" {
  @test.assert_eq(resolved("/srv/git", "/acme/app.git"), "/srv/git/acme/app")
  @test.assert_eq(resolved("/srv/git/", "/acme/app"), "/srv/git/acme/app")
  @test.assert_eq(resolved(".", "/app.git"), "./app")
}

///|
test "serve --http: paths that could climb out of the root are rejected" {
  // The path arrives from an unauthenticated client, so a traversal here
  // would expose the whole filesystem.
  for hostile in [
    "/../../etc/passwd", "/acme/../../root", "//etc/passwd", "/..",
    "/a/..%2f", "/a\\b", "",
  ] {
    @test.assert_eq(resolved("/srv/git", hostile), "<rejected>")
  }
}

///|
test "serve --http: an empty repository path is rejected" {
  @test.assert_eq(resolved("/srv/git", "/"), "<rejected>")
}

///|
test "serve --http: no token configured serves anonymously" {
  assert_true(http_token_ok(None, None))
  assert_true(http_token_ok(Some("Bearer anything"), None))
}

///|
test "serve --http: a configured token is required and must match exactly" {
  assert_true(http_token_ok(Some("Bearer s3cret"), Some("s3cret")))
  assert_true(!http_token_ok(None, Some("s3cret")))
  assert_true(!http_token_ok(Some("Bearer wrong"), Some("s3cret")))
  // A matching prefix is not a match.
  assert_true(!http_token_ok(Some("Bearer s3cretX"), Some("s3cret")))
  assert_true(!http_token_ok(Some("Bearer s3cre"), Some("s3cret")))
  // Only the Bearer scheme is accepted.
  assert_true(!http_token_ok(Some("Basic s3cret"), Some("s3cret")))
  assert_true(!http_token_ok(Some("s3cret"), Some("s3cret")))
}

///|
test "serve --http: query parameters are picked out by name" {
  @test.assert_eq(
    http_query_param("service=git-upload-pack", "service").unwrap_or("<none>"),
    "git-upload-pack",
  )
  @test.assert_eq(
    http_query_param("a=1&service=git-receive-pack&b=2", "service").unwrap_or(
      "<none>",
    ),
    "git-receive-pack",
  )
  @test.assert_eq(
    http_query_param("a=1", "service").unwrap_or("<none>"),
    "<none>",
  )
  // A parameter whose name is a suffix of another must not match it.
  @test.assert_eq(
    http_query_param("xservice=no", "service").unwrap_or("<none>"),
    "<none>",
  )
}
