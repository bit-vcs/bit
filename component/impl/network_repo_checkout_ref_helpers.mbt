///| WASM Component network checkout ref update helpers

///|
fn net_branch_name_from_refname(refname : String) -> String {
  if refname.has_prefix("refs/heads/") {
    return String::unsafe_substring(refname, start=11, end=refname.length())
  }
  "main"
}

///|
fn net_write_ref_oid(
  fs : &@bit.FileSystem,
  full_path : String,
  commit_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  fs.mkdir_p(net_parent_dir(full_path))
  fs.write_string(full_path, commit_id.to_hex() + "\n")
}

///|
fn net_write_local_checkout_ref(
  fs : &@bit.FileSystem,
  git_dir : String,
  refname : String,
  commit_id : @bit.ObjectId,
) -> Unit raise @bit.GitError {
  let branch_name = net_branch_name_from_refname(refname)
  fs.write_string(
    join_path(git_dir, "HEAD"),
    "ref: refs/heads/\{branch_name}\n",
  )
  net_write_ref_oid(
    fs,
    join_path(git_dir, "refs/heads/" + branch_name),
    commit_id,
  )
}
