///| GitHub sync pull logic

///|
pub struct SyncPullResult {
  created : Int
  updated : Int
  skipped : Int
  conflicts : Array[String]
}

///|
pub async fn github_sync_pull_issues(
  hub : @hub.Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  repo : String,
  since : String,
  state : String,
  conflict_policy : String,
) -> SyncPullResult raise @bit.GitError {
  let gh_issues = github_list_issues(repo, since~, state~)
  let mut created = 0
  let mut updated = 0
  let mut skipped = 0
  let conflicts : Array[String] = []
  let now = clock.now()
  for gh_issue in gh_issues {
    let existing_link = hub.find_sync_link_by_remote(
      objects, "github", repo, gh_issue.number,
    )
    match existing_link {
      None => {
        // New issue -- import it
        let issue = @hub.gh_issue_to_issue(gh_issue)
        let work_item = issue.to_work_item()
        ignore(
          hub.store.put_record(
            objects,
            refs,
            clock,
            @hub.work_item_meta_key(issue.id()),
            @hub.canonical_work_item_record_kind(),
            work_item.serialize(),
            "github-sync",
          ),
        )
        // Create SyncLink
        let link = @hub.SyncLink::new(
          issue.id(),
          "issue",
          "github",
          repo,
          remote_number=gh_issue.number,
          remote_node_id=gh_issue.node_id,
          last_pull_at=now,
          remote_updated_at=@hub.parse_iso8601_to_unix(gh_issue.updated_at),
        )
        hub.put_sync_link(objects, refs, clock, link)
        created += 1
      }
      Some(link) => {
        // Existing -- check conflict policy
        let gh_updated = @hub.parse_iso8601_to_unix(gh_issue.updated_at)
        let local_issue = hub.get_issue(objects, link.local_id())
        let should_update = match conflict_policy {
          "github-wins" => true
          "bit-wins" => false
          "manual" => {
            match local_issue {
              Some(loc) =>
                if loc.updated_at() > link.last_pull_at() &&
                  gh_updated > link.remote_updated_at() {
                  conflicts.push("#\{gh_issue.number} \{gh_issue.title}")
                  false
                } else {
                  gh_updated > link.remote_updated_at()
                }
              _ => gh_updated > link.remote_updated_at()
            }
          }
          _ => {
            // newer-wins (default)
            match local_issue {
              Some(loc) => gh_updated > loc.updated_at()
              None => true
            }
          }
        }
        if should_update {
          let issue = @hub.gh_issue_to_issue(
            gh_issue, existing_id=link.local_id(),
          )
          let work_item = issue.to_work_item()
          ignore(
            hub.store.put_record(
              objects,
              refs,
              clock,
              @hub.work_item_meta_key(link.local_id()),
              @hub.canonical_work_item_record_kind(),
              work_item.serialize(),
              "github-sync",
            ),
          )
          // Update SyncLink
          let updated_link = @hub.SyncLink::new(
            link.local_id(),
            "issue",
            "github",
            repo,
            remote_number=gh_issue.number,
            remote_node_id=gh_issue.node_id,
            last_pull_at=now,
            remote_updated_at=gh_updated,
          )
          hub.put_sync_link(objects, refs, clock, updated_link)
          updated += 1
        } else {
          skipped += 1
        }
      }
    }
  }
  { created, updated, skipped, conflicts }
}
