///| Pure policy logic for agent PR validation and auto-review.

///|
/// Evaluate a validation command result into a ReviewResult.
pub fn evaluate_validation(exit_code : Int, output : String) -> ReviewResult {
  if exit_code == 0 {
    ReviewResult::Approved
  } else {
    ReviewResult::Rejected("validation failed (exit \{exit_code}): \{output}")
  }
}

///|
/// Determine whether the agent should auto-review this PR.
pub fn should_auto_review(
  pr : @collab.PullRequest,
  config : AgentConfig,
) -> Bool {
  // Only review Open PRs targeting our branch, not authored by us
  pr.state() == @collab.PrState::Open &&
  pr.target_branch() == "refs/heads/" + config.target_branch &&
  pr.author() != config.agent_id
}

///|
/// Submit a validation review for a PR.
pub fn submit_validation_review(
  collab : @collab.Collab,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  pr_id : String,
  reviewer_id : String,
  result : ReviewResult,
  commit_id : @git.ObjectId,
) -> Unit {
  let (verdict, body) = match result {
    Approved => (@collab.ReviewVerdict::Approved, "validation passed")
    Rejected(reason) => (@collab.ReviewVerdict::RequestChanges, reason)
    ValidationError(err) =>
      (@collab.ReviewVerdict::Comment, "validation error: \{err}")
  }
  ignore(
    collab.submit_review(
      objects, refs, clock, pr_id, reviewer_id, verdict, body, commit_id,
    ),
  ) catch {
    _ => ()
  }
}
