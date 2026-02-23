///|
async fn handle_repack(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let mut all = false
  let mut delete_redundant = false
  let mut quiet = false
  for arg in args {
    if arg.has_prefix("-") && not(arg.has_prefix("--")) && arg.length() > 1 {
      // Parse combined short flags like -ad, -adq, etc.
      for i in 1..<arg.length() {
        let ch = arg[i]
        match ch {
          'a' => all = true
          'A' => {
            all = true
            delete_redundant = true
          }
          'd' => delete_redundant = true
          'q' => quiet = true
          _ => ()
        }
      }
    }
  }
  ignore(all)
  // Use gitlib's repack_repo
  let result = @bitlib.repack_repo(fs, fs, root)
  match result {
    Some(info) => {
      if not(quiet) {
        let hex = info.pack_id.to_hex()
        print_line(
          "Repacked \{info.object_count} objects into pack-\{String::unsafe_substring(hex, start=0, end=8)}",
        )
      }
      if all && delete_redundant {
        let git_dir = root + "/.git"
        let pack_dir = git_dir + "/objects/pack"
        let new_pack_name = "pack-" + info.pack_id.to_hex() + ".pack"
        let entries = fs.readdir(pack_dir) catch { _ => [] }
        for entry in entries {
          if entry.has_suffix(".pack") && entry != new_pack_name {
            let stem = midx_pack_stem(entry)
            fs.remove_file(pack_dir + "/" + entry) catch {
              _ => ()
            }
            fs.remove_file(pack_dir + "/" + stem + ".idx") catch {
              _ => ()
            }
            fs.remove_file(pack_dir + "/" + stem + ".rev") catch {
              _ => ()
            }
            fs.remove_file(pack_dir + "/" + stem + ".bitmap") catch {
              _ => ()
            }
          }
        }
      }
    }
    None => if not(quiet) { print_line("Nothing to repack.") }
  }
}

///|
