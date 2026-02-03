///| Import/upsert helpers for external PRs and Issues

///|
pub struct ImportStats {
  created : Int
  updated : Int
}

///|
pub fn ImportStats::new(created : Int, updated : Int) -> ImportStats {
  { created, updated }
}

///|
pub fn ImportStats::created(self : ImportStats) -> Int {
  self.created
}

///|
pub fn ImportStats::updated(self : ImportStats) -> Int {
  self.updated
}

///|
pub fn Collab::import_prs(
  self : Collab,
  fs : &@git.FileSystem,
  backing_fs : &@git.RepoFileSystem,
  prs : Array[PullRequest],
) -> ImportStats raise @git.GitError {
  if prs.length() == 0 {
    return ImportStats::new(0, 0)
  }
  let current = load_counter(backing_fs, self.git_dir)
  let mut max_id = current - 1
  for pr in prs {
    let value = parse_int(pr.id())
    if value > max_id {
      max_id = value
    }
  }
  let mut next_id = current
  if max_id >= next_id {
    next_id = max_id + 1
  }
  let mut created = 0
  let mut updated = 0
  for pr in prs {
    let pr_data = pr.serialize()
    let (pr_blob_id, pr_compressed) = @git.create_blob_string(pr_data)
    write_object_bytes(fs, self.git_dir, pr_blob_id, pr_compressed)
    let existing = self.get_pr(backing_fs, pr.id())
    match existing {
      Some(_) => {
        update_pr_data(fs, backing_fs, self.git_dir, pr.id(), pr_blob_id)
        updated += 1
      }
      None => {
        update_collab_tree(
          fs,
          backing_fs,
          self.git_dir,
          pr.id(),
          pr_blob_id,
          next_id,
        )
        created += 1
      }
    }
  }
  if next_id > self.next_id {
    self.next_id = next_id
  }
  ImportStats::new(created, updated)
}

///|
pub fn Collab::import_issues(
  self : Collab,
  fs : &@git.FileSystem,
  backing_fs : &@git.RepoFileSystem,
  issues : Array[Issue],
) -> ImportStats raise @git.GitError {
  if issues.length() == 0 {
    return ImportStats::new(0, 0)
  }
  let current = load_issue_counter(backing_fs, self.git_dir)
  let mut max_id = current - 1
  for issue in issues {
    let value = parse_int(issue.id())
    if value > max_id {
      max_id = value
    }
  }
  let mut next_id = current
  if max_id >= next_id {
    next_id = max_id + 1
  }
  let mut created = 0
  let mut updated = 0
  for issue in issues {
    let issue_data = issue.serialize()
    let (issue_blob_id, issue_compressed) = @git.create_blob_string(issue_data)
    write_object_bytes(fs, self.git_dir, issue_blob_id, issue_compressed)
    let existing = self.get_issue(backing_fs, issue.id())
    match existing {
      Some(_) => {
        update_issue_data(
          fs,
          backing_fs,
          self.git_dir,
          issue.id(),
          issue_blob_id,
        )
        updated += 1
      }
      None => {
        update_issues_tree(
          fs,
          backing_fs,
          self.git_dir,
          issue.id(),
          issue_blob_id,
          next_id,
        )
        created += 1
      }
    }
  }
  ImportStats::new(created, updated)
}
