///| Diff-tree pure helper functions

///|
/// Truncate a hex string to the given abbreviation length.
pub fn diff_tree_abbrev_hex(hex : String, abbrev : Int?) -> String {
  match abbrev {
    None => hex
    Some(n) => {
      let len = if n < 4 { 4 } else if n > 40 { 40 } else { n }
      String::unsafe_substring(hex, start=0, end=len)
    }
  }
}

///|
/// Check if a diff status character matches a filter string.
pub fn diff_tree_filter_matches(filter : String?, status : String) -> Bool {
  match filter {
    None => true
    Some(f) => f.contains(status)
  }
}
