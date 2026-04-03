///| Conversion functions between GitHub API types and bit hub types

///|
/// Describes what changed between a local Issue and a GitHub GhIssue
pub struct SyncDiff {
  title_changed : Bool
  body_changed : Bool
  state_changed : Bool
  labels_changed : Bool
  assignees_changed : Bool
  has_changes : Bool
}

///|
/// Convert a GitHub API issue to a local Issue
pub fn gh_issue_to_issue(
  gh : GhIssue,
  existing_id? : String = "",
) -> Issue {
  let created_at = parse_iso8601_to_unix(gh.created_at)
  let updated_at = parse_iso8601_to_unix(gh.updated_at)
  let author = gh.user
  let state : IssueState = if gh.state == "closed" {
    IssueState::Closed
  } else {
    IssueState::Open
  }
  let id = if existing_id != "" {
    existing_id
  } else {
    generate_entity_id("issue", author, created_at, gh.title + "\n" + gh.body)
  }
  Issue::new(
    id,
    gh.title,
    gh.body,
    author,
    created_at,
    updated_at,
    state,
    labels=gh.labels,
    assignees=gh.assignees,
  )
}

///|
/// Compare a local Issue with a GitHub GhIssue and return a SyncDiff
pub fn issue_diff_for_github(
  current : Issue,
  _link : SyncLink,
  gh : GhIssue,
) -> SyncDiff {
  let gh_state : IssueState = if gh.state == "closed" {
    IssueState::Closed
  } else {
    IssueState::Open
  }
  let title_changed = current.title != gh.title
  let body_changed = current.body != gh.body
  let state_changed = current.state != gh_state
  let labels_changed = !string_arrays_equal(current.labels, gh.labels)
  let assignees_changed = !string_arrays_equal(current.assignees, gh.assignees)
  let has_changes = title_changed ||
    body_changed ||
    state_changed ||
    labels_changed ||
    assignees_changed
  { title_changed, body_changed, state_changed, labels_changed, assignees_changed, has_changes }
}

///|
/// Convert a GitHub API pull request to a local PullRequest
pub fn gh_pr_to_pull_request(
  gh : GhPullRequest,
  existing_id? : String = "",
) -> PullRequest {
  let created_at = parse_iso8601_to_unix(gh.created_at)
  let updated_at = parse_iso8601_to_unix(gh.updated_at)
  let state = match gh.state {
    "merged" => PrState::Merged
    "closed" => PrState::Closed
    _ => PrState::Open
  }
  let id = if existing_id != "" {
    existing_id
  } else {
    generate_entity_id("pr", gh.user, created_at, gh.title + "\n" + gh.body)
  }
  let source_branch = "refs/heads/" + gh.head_ref
  let target_branch = "refs/heads/" + gh.base_ref
  let source_repo : String? = if gh.head_repo.length() > 0 {
    Some(gh.head_repo)
  } else {
    None
  }
  PullRequest::new(
    id,
    gh.title,
    gh.body,
    source_branch,
    @bit.ObjectId::zero(),
    target_branch,
    @bit.ObjectId::zero(),
    gh.user,
    created_at,
    updated_at,
    state,
    gh.labels,
    source_repo=source_repo,
    source_ref=Some(source_branch),
  )
}

///|
/// Compare a local PullRequest with a GitHub GhPullRequest and return a SyncDiff
pub fn pr_diff_for_github(
  current : PullRequest,
  _link : SyncLink,
  gh : GhPullRequest,
) -> SyncDiff {
  let gh_state : PrState = match gh.state {
    "merged" => PrState::Merged
    "closed" => PrState::Closed
    _ => PrState::Open
  }
  let title_changed = current.title != gh.title
  let body_changed = current.body != gh.body
  let state_changed = current.state != gh_state
  let labels_changed = !string_arrays_equal(current.labels, gh.labels)
  let has_changes = title_changed ||
    body_changed ||
    state_changed ||
    labels_changed
  {
    title_changed,
    body_changed,
    state_changed,
    labels_changed,
    assignees_changed: false,
    has_changes,
  }
}

///|
fn string_arrays_equal(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let sorted_a = a.copy()
  let sorted_b = b.copy()
  sorted_a.sort_by(fn(x, y) { x.compare(y) })
  sorted_b.sort_by(fn(x, y) { x.compare(y) })
  for i = 0; i < sorted_a.length(); i = i + 1 {
    if sorted_a[i] != sorted_b[i] {
      return false
    }
  }
  true
}
