///| WASM Component status staged result helpers

///|
struct StatusStagedChanges {
  staged_added : Array[String]
  staged_modified : Array[String]
  staged_deleted : Array[String]
} derive(Show, Eq)

///|
fn status_collect_staged_changes(
  fs : &@bit.RepoFileSystem,
  git_dir : String,
  entries : Array[@bitlib.IndexEntry],
) -> StatusStagedChanges raise @bit.GitError {
  let staged_index_map : Map[String, @bitlib.IndexEntry] = {}
  for entry in entries {
    staged_index_map[entry.path] = entry
  }
  let staged_modified : Array[String] = []
  let staged_deleted : Array[String] = []
  status_collect_staged_head_changes(
    fs, git_dir, staged_index_map, staged_modified, staged_deleted,
  )
  let staged_added : Array[String] = []
  for item in staged_index_map.to_array() {
    let (path, _) = item
    staged_added.push(path)
  }
  StatusStagedChanges::{ staged_added, staged_modified, staged_deleted }
}
