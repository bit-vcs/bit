///| Tests for GitHub conversion functions

///|
fn make_gh_issue_json(json_str : String) -> GhIssue {
  let parsed = @json.parse(json_str) catch { _ => abort("invalid json") }
  guard parsed is Json::Object(obj) else { abort("not object") }
  GhIssue::from_json(obj)
}

///|
test "github_convert: gh_issue_to_issue basic" {
  let json =
    #|{"number":42,"node_id":"I_kwDOxxx","title":"Bug report","body":"description","state":"open","user":{"login":"alice"},"labels":[{"name":"bug"}],"assignees":[{"login":"bob"}],"created_at":"2026-01-15T10:30:45Z","updated_at":"2026-01-16T10:30:45Z"}
  let gh = make_gh_issue_json(json)
  let issue = gh_issue_to_issue(gh)
  assert_eq(issue.title, "Bug report")
  assert_eq(issue.body, "description")
  assert_eq(issue.author, "alice")
  assert_eq(issue.labels, ["bug"])
  assert_eq(issue.assignees, ["bob"])
  assert_true(issue.state == IssueState::Open)
}

///|
test "github_convert: gh_issue_to_issue closed state" {
  let json =
    #|{"number":1,"node_id":"I_xx","title":"Fixed","body":"","state":"closed","user":{"login":"bob"},"labels":[],"assignees":[],"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-02T00:00:00Z"}
  let gh = make_gh_issue_json(json)
  let issue = gh_issue_to_issue(gh)
  assert_true(issue.state == IssueState::Closed)
}

///|
test "github_convert: gh_issue_to_issue with existing_id" {
  let json =
    #|{"number":42,"node_id":"I_kwDOxxx","title":"Bug","body":"desc","state":"open","user":{"login":"alice"},"labels":[],"assignees":[],"created_at":"2026-01-15T10:30:45Z","updated_at":"2026-01-16T10:30:45Z"}
  let gh = make_gh_issue_json(json)
  let issue = gh_issue_to_issue(gh, existing_id="my-custom-id")
  assert_eq(issue.id, "my-custom-id")
}

///|
test "github_convert: sync_diff detects changes" {
  let cur = Issue::new(
    "id1",
    "Old title",
    "old body",
    "alice",
    1768473045L,
    1768473045L,
    IssueState::Open,
    labels=["bug"],
  )
  let json =
    #|{"number":42,"node_id":"I_xx","title":"Old title","body":"old body","state":"closed","user":{"login":"alice"},"labels":[{"name":"bug"},{"name":"fixed"}],"assignees":[],"created_at":"2026-01-15T10:30:45Z","updated_at":"2026-01-16T10:30:45Z"}
  let gh = make_gh_issue_json(json)
  let link = SyncLink::new(
    "id1",
    "issue",
    "github",
    "owner/repo",
    remote_number=42,
  )
  let diff = issue_diff_for_github(cur, link, gh)
  assert_true(diff.state_changed)
  assert_true(diff.labels_changed)
  assert_true(!diff.title_changed)
  assert_true(!diff.body_changed)
  assert_true(diff.has_changes)
}

///|
test "github_convert: sync_diff no changes" {
  let cur = Issue::new(
    "id1",
    "Same title",
    "same body",
    "alice",
    1768473045L,
    1768473045L,
    IssueState::Open,
    labels=["bug"],
  )
  let json =
    #|{"number":42,"node_id":"I_xx","title":"Same title","body":"same body","state":"open","user":{"login":"alice"},"labels":[{"name":"bug"}],"assignees":[],"created_at":"2026-01-15T10:30:45Z","updated_at":"2026-01-16T10:30:45Z"}
  let gh = make_gh_issue_json(json)
  let link = SyncLink::new(
    "id1",
    "issue",
    "github",
    "owner/repo",
    remote_number=42,
  )
  let diff = issue_diff_for_github(cur, link, gh)
  assert_true(!diff.state_changed)
  assert_true(!diff.labels_changed)
  assert_true(!diff.title_changed)
  assert_true(!diff.body_changed)
  assert_true(!diff.has_changes)
}
