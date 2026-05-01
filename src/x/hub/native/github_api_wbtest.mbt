///| Whitebox tests for GitHub API helpers.

///|
fn github_api_test_repo_object(text : String) -> Map[String, Json] {
  let parsed = @json.parse(text) catch { _ => abort("invalid json") }
  guard parsed is Json::Object(obj) else { abort("expected repo JSON object") }
  obj
}

///|
test "github api: repo permissions allow org push access" {
  let obj = github_api_test_repo_object(
    "{\"full_name\":\"org/repo\",\"permissions\":{\"admin\":false,\"maintain\":false,\"push\":true,\"triage\":true,\"pull\":true}}",
  )
  assert_true(github_repo_permissions_allow_push(obj))
}

///|
test "github api: repo permissions allow admin without owner match" {
  let obj = github_api_test_repo_object(
    "{\"full_name\":\"org/repo\",\"permissions\":{\"admin\":true,\"maintain\":false,\"push\":false,\"pull\":true}}",
  )
  assert_true(github_repo_permissions_allow_push(obj))
}

///|
test "github api: repo permissions reject read-only access" {
  let obj = github_api_test_repo_object(
    "{\"full_name\":\"org/repo\",\"permissions\":{\"admin\":false,\"maintain\":false,\"push\":false,\"pull\":true}}",
  )
  assert_false(github_repo_permissions_allow_push(obj))
}
