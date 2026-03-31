///|
test "component impl: porcelain_lines_from_status renders stable status lines" {
  inspect(
    porcelain_lines_from_status(StatusResult::{
      staged_added: ["added.txt"],
      staged_modified: ["changed.txt"],
      staged_deleted: ["deleted.txt"],
      unstaged_modified: ["dirty.txt"],
      unstaged_deleted: ["gone.txt"],
      untracked: ["new.txt"],
    }),
    content="[\"A  added.txt\", \"M  changed.txt\", \"D  deleted.txt\", \" M dirty.txt\", \" D gone.txt\", \"?? new.txt\"]",
  )
}
