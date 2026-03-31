///| WASM Component clone target selection helpers

///|
fn net_select_clone_target(
  refs : Array[(@bit.ObjectId, String)],
  symrefs : Map[String, String],
  branch : String,
) -> (String, @bit.ObjectId)? {
  if branch.length() == 0 {
    return @protocol.select_default_ref(refs, symrefs)
  }
  let target_ref = "refs/heads/" + branch
  for item in refs {
    let (id, refname) = item
    if refname == target_ref {
      return Some((refname, id))
    }
  }
  None
}
