///| Tree mode helpers

///|
fn is_tree_mode(mode : String) -> Bool {
  mode == "040000" || mode == "40000"
}
