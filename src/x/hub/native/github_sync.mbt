///| GitHub sync pull and push logic

///|
pub struct SyncPushChange {
  action : String // "create" or "update"
  local_id : String
  title : String
  remote_number : Int // 0 for create
  state_change : String // "" or "open->closed" etc.
  title_change : String // "" or "old->new"
  labels_change : String // "" or "[old]->[new]"
  is_destructive : Bool // state changes, body overwrites
}

///|
pub struct SyncPushResult {
  created : Int
  updated : Int
  errors : Array[String]
}

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

///|
pub async fn github_sync_plan_push(
  hub : @hub.Hub,
  objects : &@lib.ObjectStore,
  repo : String,
) -> Array[SyncPushChange] raise @bit.GitError {
  let changes : Array[SyncPushChange] = []
  let issues = hub.list_issues(objects)
  let links = hub.list_sync_links(objects, repo=repo)
  // Build lookup: local_id -> SyncLink
  let link_map : Map[String, @hub.SyncLink] = {}
  for link in links {
    if link.local_kind() == "issue" {
      link_map.set(link.local_id(), link)
    }
  }
  for issue in issues {
    match link_map.get(issue.id()) {
      Some(link) => {
        // Check if local is newer than last push
        if issue.updated_at() > link.last_push_at() {
          let diff = compute_push_diff(issue, link)
          changes.push(diff)
        }
      }
      None => {
        // No link -- new issue to create on GitHub
        // Skip sub-issues (have parent_id)
        if issue.parent_id is Some(_) {
          continue
        }
        let labels_str = issue.labels().join(", ")
        changes.push(
          {
            action: "create",
            local_id: issue.id(),
            title: issue.title(),
            remote_number: 0,
            state_change: "",
            title_change: "",
            labels_change: if labels_str.length() > 0 {
              "[\{labels_str}]"
            } else {
              ""
            },
            is_destructive: false,
          },
        )
      }
    }
  }
  changes
}

///|
fn compute_push_diff(
  issue : @hub.Issue,
  link : @hub.SyncLink,
) -> SyncPushChange {
  // For updates, we don't have the remote state cached locally,
  // so we note that the local has changed since last push.
  let state_str = issue.state().to_string()
  let labels_str = issue.labels().join(", ")
  {
    action: "update",
    local_id: issue.id(),
    title: issue.title(),
    remote_number: link.remote_number(),
    state_change: state_str,
    title_change: "",
    labels_change: if labels_str.length() > 0 {
      "[\{labels_str}]"
    } else {
      ""
    },
    is_destructive: true,
  }
}

///|
pub async fn github_sync_execute_push(
  hub : @hub.Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  repo : String,
  changes : Array[SyncPushChange],
) -> SyncPushResult raise @bit.GitError {
  let mut created = 0
  let mut updated = 0
  let errors : Array[String] = []
  let now = clock.now()
  for change in changes {
    let issue = hub.get_issue(objects, change.local_id)
    guard issue is Some(loc) else { continue }
    let state_str = loc.state().to_string()
    match change.action {
      "create" => {
        let gh_issue = github_create_issue(
          repo, loc.title(), loc.body(), loc.labels(), loc.assignees(),
        ) catch {
          err => {
            errors.push("create \{loc.title()}: \{err}")
            continue
          }
        }
        // Create SyncLink
        let link = @hub.SyncLink::new(
          loc.id(),
          "issue",
          "github",
          repo,
          remote_number=gh_issue.number,
          remote_node_id=gh_issue.node_id,
          last_push_at=now,
          remote_updated_at=@hub.parse_iso8601_to_unix(gh_issue.updated_at),
        )
        hub.put_sync_link(objects, refs, clock, link)
        created += 1
      }
      "update" => {
        let existing_link = hub.get_sync_link(objects, change.local_id, "github")
        guard existing_link is Some(link) else { continue }
        let _ = github_update_issue(
          repo,
          link.remote_number(),
          title=loc.title(),
          body=loc.body(),
          state=state_str,
          labels=loc.labels(),
          assignees=loc.assignees(),
        ) catch {
          err => {
            errors.push("update #\{link.remote_number()}: \{err}")
            continue
          }
        }
        // Update SyncLink
        let updated_link = @hub.SyncLink::new(
          loc.id(),
          "issue",
          "github",
          repo,
          remote_number=link.remote_number(),
          remote_node_id=link.remote_node_id(),
          last_push_at=now,
          last_pull_at=link.last_pull_at(),
          remote_updated_at=now,
        )
        hub.put_sync_link(objects, refs, clock, updated_link)
        updated += 1
      }
      _ => ()
    }
  }
  { created, updated, errors }
}
