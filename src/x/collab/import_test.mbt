///| Tests for collab import helpers

///|
test "import pr: creates" {
  let (_fs, objects, refs, clock) = setup_repo_with_branch()
  let collab = Collab::init(objects, refs)
  let source_id = refs.resolve("refs/heads/feature")
  guard source_id is Some(sid) else { panic() }
  let target_id = refs.resolve("refs/heads/main")
  guard target_id is Some(tid) else { panic() }
  let pr = PullRequest::new(
    "10",
    "Imported PR",
    "Imported body",
    "refs/heads/feature",
    sid,
    "refs/heads/main",
    tid,
    "gh-user",
    1700000000L,
    1700000100L,
    PrState::Open,
    ["imported"],
  )
  let stats = collab.import_prs(objects, refs, clock, [pr])
  assert_eq(stats.created(), 1)
  assert_eq(stats.updated(), 0)
  let stored = collab.get_pr(objects, "10")
  guard stored is Some(val) else { panic() }
  assert_eq(val.title(), "Imported PR")
}

///|
test "import pr: updates existing" {
  let (_fs, objects, refs, clock) = setup_repo_with_branch()
  let collab = Collab::init(objects, refs)
  let created = collab.create_pr(
    objects, refs, clock, "Original", "Body", "refs/heads/feature", "refs/heads/main",
    "alice@example.com",
  )
  let pr_id = created.id()
  let source_id = refs.resolve("refs/heads/feature")
  guard source_id is Some(sid) else { panic() }
  let target_id = refs.resolve("refs/heads/main")
  guard target_id is Some(tid) else { panic() }
  let pr = PullRequest::new(
    pr_id,
    "Updated Title",
    "Updated Body",
    "refs/heads/feature",
    sid,
    "refs/heads/main",
    tid,
    "gh-user",
    1707000000L,
    1707000200L,
    PrState::Closed,
    ["sync"],
  )
  let stats = collab.import_prs(objects, refs, clock, [pr])
  assert_eq(stats.created(), 0)
  assert_eq(stats.updated(), 1)
  let stored = collab.get_pr(objects, pr_id)
  guard stored is Some(val) else { panic() }
  assert_eq(val.title(), "Updated Title")
  assert_eq(val.state(), PrState::Closed)
}

///|
test "import issue: creates" {
  let (_fs, objects, refs, clock) = setup_repo_with_branch()
  let collab = Collab::init(objects, refs)
  let issue = Issue::new(
    "7",
    "Imported Issue",
    "Issue body",
    "gh-user",
    1700000000L,
    1700000100L,
    IssueState::Open,
    labels=["bug"],
    assignees=["alice"],
  )
  let stats = collab.import_issues(objects, refs, clock, [issue])
  assert_eq(stats.created(), 1)
  assert_eq(stats.updated(), 0)
  let created = collab.create_issue(
    objects, refs, clock, "Next", "Body", "alice@example.com",
  )
  assert_true(created.id().length() > 0)
}
