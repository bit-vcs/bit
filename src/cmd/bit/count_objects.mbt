///| git count-objects - count unpacked number of objects and their disk consumption

///|
async fn handle_count_objects(args : Array[String]) -> Unit raise Error {
  let mut verbose = false
  let mut human_readable = false
  for arg in args {
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git count-objects [-v] [-H]",
          summary="Count unpacked number of objects and their disk consumption.",
        )
        return
      }
      "-v" | "--verbose" => verbose = true
      "-H" | "--human-readable" => human_readable = true
      _ if arg.has_prefix("-") => warn_unimplemented_arg("count-objects", arg)
      _ => ()
    }
  }
  let root = get_work_root()
  let fs = OsFs::new()
  let rfs : &@bitcore.RepoFileSystem = fs
  let git_dir = resolve_git_dir(rfs, root)
  let objects_dir = git_dir + "/objects"
  // Count loose objects
  let mut loose_count = 0
  let mut loose_size : Int64 = 0L
  for i = 0; i < 256; i = i + 1 {
    let hex = count_objects_hex_byte(i)
    let subdir = objects_dir + "/" + hex
    if !rfs.is_dir(subdir) {
      continue
    }
    let entries = rfs.readdir(subdir) catch { _ => continue }
    for entry in entries {
      // Skip non-object files
      if entry == "." || entry == ".." {
        continue
      }
      loose_count += 1
      // Read file to get size (approximation: file size on disk)
      let fpath = subdir + "/" + entry
      let data = rfs.read_file(fpath) catch { _ => continue }
      loose_size += data.length().to_int64()
    }
  }
  if !verbose {
    let size_kb = (loose_size + 1023L) / 1024L
    if human_readable {
      print_line(
        "\{loose_count} objects, \{count_objects_format_size(loose_size, human_readable)}",
      )
    } else {
      print_line("\{loose_count} objects, \{size_kb} kilobytes")
    }
    return
  }
  // Verbose mode: also count packs
  let pack_dir = objects_dir + "/pack"
  let mut pack_count = 0
  let mut pack_size : Int64 = 0L
  let mut garbage_count = 0
  let mut garbage_size : Int64 = 0L
  if rfs.is_dir(pack_dir) {
    let pack_entries = rfs.readdir(pack_dir) catch { _ => [] }
    for entry in pack_entries {
      if entry.has_suffix(".pack") {
        pack_count += 1
        let ppath = pack_dir + "/" + entry
        let data = rfs.read_file(ppath) catch { _ => continue }
        pack_size += data.length().to_int64()
      } else if entry.has_suffix(".idx") ||
        entry.has_suffix(".keep") ||
        entry.has_suffix(".rev") ||
        entry.has_suffix(".bitmap") ||
        entry.has_suffix(".mtimes") {
        // These are expected pack-related files
        ()
      } else if entry != "." &&
        entry != ".." &&
        !entry.has_prefix("multi-pack-index") {
        garbage_count += 1
        let gpath = pack_dir + "/" + entry
        let data = rfs.read_file(gpath) catch { _ => continue }
        garbage_size += data.length().to_int64()
      }
    }
  }
  if human_readable {
    print_line("count: \{loose_count}")
    print_line("size: \{count_objects_format_size(loose_size, true)}")
    print_line("in-pack: 0")
    print_line("packs: \{pack_count}")
    print_line("size-pack: \{count_objects_format_size(pack_size, true)}")
    print_line("prune-packable: 0")
    print_line("garbage: \{garbage_count}")
    print_line("size-garbage: \{count_objects_format_size(garbage_size, true)}")
  } else {
    let size_kb = (loose_size + 1023L) / 1024L
    let pack_size_kb = (pack_size + 1023L) / 1024L
    let garbage_size_kb = (garbage_size + 1023L) / 1024L
    print_line("count: \{loose_count}")
    print_line("size: \{size_kb}")
    print_line("in-pack: 0")
    print_line("packs: \{pack_count}")
    print_line("size-pack: \{pack_size_kb}")
    print_line("prune-packable: 0")
    print_line("garbage: \{garbage_count}")
    print_line("size-garbage: \{garbage_size_kb}")
  }
}

///|
fn count_objects_hex_byte(n : Int) -> String {
  let hi = n / 16
  let lo = n % 16
  let hex_char = fn(v : Int) -> String {
    match v {
      0 => "0"
      1 => "1"
      2 => "2"
      3 => "3"
      4 => "4"
      5 => "5"
      6 => "6"
      7 => "7"
      8 => "8"
      9 => "9"
      10 => "a"
      11 => "b"
      12 => "c"
      13 => "d"
      14 => "e"
      _ => "f"
    }
  }
  hex_char(hi) + hex_char(lo)
}

///|
fn count_objects_format_size(bytes : Int64, human : Bool) -> String {
  if !human {
    let kb = (bytes + 1023L) / 1024L
    return "\{kb} kilobytes"
  }
  if bytes < 1024L {
    return "\{bytes} bytes"
  }
  let kb = bytes / 1024L
  if kb < 1024L {
    return "\{kb} KiB"
  }
  let mb = kb / 1024L
  if mb < 1024L {
    return "\{mb} MiB"
  }
  let gb = mb / 1024L
  "\{gb} GiB"
}
