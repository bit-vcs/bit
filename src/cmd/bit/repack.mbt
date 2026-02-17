///|
async fn handle_repack(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let mut all = false
  let mut delete_redundant = false
  let mut quiet = false
  for arg in args {
    match arg {
      "-a" => all = true
      "-A" => {
        all = true
        delete_redundant = true
      }
      "-d" => delete_redundant = true
      "-q" => quiet = true
      _ => ()
    }
  }
  ignore(all)
  ignore(delete_redundant)
  // Use gitlib's repack_repo
  let result = @bitlib.repack_repo(fs, fs, root)
  match result {
    Some(info) =>
      if not(quiet) {
        let hex = info.pack_id.to_hex()
        print_line(
          "Repacked \{info.object_count} objects into pack-\{String::unsafe_substring(hex, start=0, end=8)}",
        )
      }
    None => if not(quiet) { print_line("Nothing to repack.") }
  }
}

///|
