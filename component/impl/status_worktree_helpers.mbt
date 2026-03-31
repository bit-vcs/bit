///| WASM Component status worktree-scan helpers

///|
struct StatusWorktreeChanges {
  untracked : Array[String]
  unstaged_modified : Array[String]
  unstaged_deleted : Array[String]
} derive(Show, Eq)

///|
fn status_collect_worktree_changes(
  fs : &@bit.RepoFileSystem,
  root : String,
  entries : Array[@bitlib.IndexEntry],
) -> StatusWorktreeChanges raise @bit.GitError {
  let index_map : Map[String, @bitlib.IndexEntry] = {}
  for entry in entries {
    index_map[entry.path] = entry
  }
  let files = @bitlib.list_working_files(fs, root)
  files.sort()
  let visited : Map[String, Bool] = {}
  let untracked : Array[String] = []
  let unstaged_modified : Array[String] = []
  for rel_path in files {
    visited[rel_path] = true
    match index_map.get(rel_path) {
      Some(index_entry) => {
        let abs_path = join_path(root, rel_path)
        let content = fs.read_file(abs_path) catch { _ => continue }
        let worktree_id = @bit.hash_blob(content)
        if worktree_id != index_entry.id {
          unstaged_modified.push(rel_path)
        }
      }
      None => untracked.push(rel_path)
    }
  }
  let unstaged_deleted : Array[String] = []
  for entry in entries {
    if visited.get(entry.path) is Some(_) {
      continue
    }
    let abs_path = join_path(root, entry.path)
    if not(fs.is_file(abs_path)) {
      unstaged_deleted.push(entry.path)
    }
  }
  StatusWorktreeChanges::{ untracked, unstaged_modified, unstaged_deleted }
}
