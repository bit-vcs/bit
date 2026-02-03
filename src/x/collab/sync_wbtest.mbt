///| Whitebox tests for collab sync merge logic

///|
fn setup_sync_repo() -> (@git.TestFs, String) {
  let fs = @git.TestFs::new()
  fs.mkdir_p("/repo/.git")
  (fs, "/repo/.git")
}

///|
fn write_blob(
  fs : @git.TestFs,
  git_dir : String,
  content : String,
) -> @git.ObjectId {
  let (id, compressed) = @git.create_blob_string(content)
  write_object_bytes(fs, git_dir, id, compressed) catch {
    _ => panic()
  }
  id
}

///|
fn write_tree(
  fs : @git.TestFs,
  git_dir : String,
  entries : Array[@git.TreeEntry],
) -> @git.ObjectId {
  let (id, compressed) = @git.create_tree(entries)
  write_object_bytes(fs, git_dir, id, compressed) catch {
    _ => panic()
  }
  id
}

///|
fn read_blob_string(
  db : @lib.ObjectDb,
  fs : @git.TestFs,
  id : @git.ObjectId,
) -> String {
  let obj = db.get(fs, id) catch { _ => None }
  guard obj is Some(blob) else { return "" }
  @utf8.decode_lossy(blob.data[:])
}

///|
fn parse_int_simple(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  result
}

///|
test "sync: merge issue dir prefers newer issue.data" {
  let (fs, git_dir) = setup_sync_repo()
  let db = @lib.ObjectDb::load_lazy(fs, git_dir)
  let old_issue = Issue::new(
    "1",
    "Old",
    "Old body",
    "alice",
    10L,
    10L,
    IssueState::Open,
  )
  let new_issue = Issue::new(
    "1",
    "New",
    "New body",
    "alice",
    10L,
    20L,
    IssueState::Closed,
  )
  let old_blob = write_blob(fs, git_dir, old_issue.serialize())
  let new_blob = write_blob(fs, git_dir, new_issue.serialize())
  let empty_tree = write_tree(fs, git_dir, [])
  let local_issue_tree = write_tree(fs, git_dir, [
    @git.TreeEntry::new("040000", "comments", empty_tree),
    @git.TreeEntry::new("100644", "issue.data", old_blob),
  ])
  let remote_issue_tree = write_tree(fs, git_dir, [
    @git.TreeEntry::new("040000", "comments", empty_tree),
    @git.TreeEntry::new("100644", "issue.data", new_blob),
  ])
  let merged = merge_issue_dir(
    fs, fs, git_dir, db, local_issue_tree, remote_issue_tree,
  )
  let merged_entries = read_tree_entries(db, fs, merged)
  let mut merged_blob = @git.ObjectId::zero()
  for entry in merged_entries {
    if entry.name == "issue.data" {
      merged_blob = entry.id
    }
  }
  assert_eq(merged_blob, new_blob)
}

///|
test "sync: merge meta keeps issue_counter" {
  let (fs, git_dir) = setup_sync_repo()
  let db = @lib.ObjectDb::load_lazy(fs, git_dir)
  let local_counter = write_blob(fs, git_dir, "5\n")
  let local_issue_counter = write_blob(fs, git_dir, "7\n")
  let remote_counter = write_blob(fs, git_dir, "3\n")
  let remote_issue_counter = write_blob(fs, git_dir, "9\n")
  let local_meta = write_tree(fs, git_dir, [
    @git.TreeEntry::new("100644", "counter", local_counter),
    @git.TreeEntry::new("100644", "issue_counter", local_issue_counter),
  ])
  let remote_meta = write_tree(fs, git_dir, [
    @git.TreeEntry::new("100644", "counter", remote_counter),
    @git.TreeEntry::new("100644", "issue_counter", remote_issue_counter),
  ])
  let merged = merge_meta_trees(
    fs,
    fs,
    git_dir,
    db,
    Some(@git.TreeEntry::new("040000", "meta", local_meta)),
    Some(@git.TreeEntry::new("040000", "meta", remote_meta)),
  )
  let merged_counter_id = find_tree_entry(db, fs, merged, "counter")
  let merged_issue_id = find_tree_entry(db, fs, merged, "issue_counter")
  guard merged_counter_id is Some(cid) else { panic() }
  guard merged_issue_id is Some(iid) else { panic() }
  let counter_text = read_blob_string(db, fs, cid)
  let issue_text = read_blob_string(db, fs, iid)
  assert_eq(parse_int_simple(counter_text), 5)
  assert_eq(parse_int_simple(issue_text), 9)
}
