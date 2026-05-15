///| git verify-tag - verify GPG signature of a tag

///|
async fn handle_verify_tag(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = find_git_dir(fs)
  let mut verbose = false
  let mut raw = false
  let mut format : String? = None
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-v" | "--verbose" => verbose = true
      "--raw" => raw = true
      "-h" | "--help" => {
        show_simple_command_help(
          "git verify-tag [-v | --verbose] [--raw] [--format=<format>] <tag>...",
          summary="Verify the GPG signature of tags.",
        )
        return
      }
      _ if arg.has_prefix("--format=") => format = Some(arg[9:].to_string())
      _ if arg.has_prefix("-") => warn_unimplemented_arg("verify-tag", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  if positional.length() == 0 {
    eprint_line(
      "usage: git verify-tag [-v | --verbose] [--raw] [--format=<format>] <tag>...",
    )
    @sys.exit(1)
    return
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let mut had_error = false
  for tag_name in positional {
    // Resolve the tag reference
    let tag_id = match @bitrepo.rev_parse(fs, git_dir, tag_name) {
      Some(id) => id
      None => {
        eprint_line("error: tag '\{tag_name}' not found.")
        had_error = true
        continue
      }
    }
    // Get the object
    match db.get(fs, tag_id) {
      Some(obj) if obj.obj_type == @bitcore.ObjectType::Tag =>
        match signing_extract_tag_signature(obj.data) {
          Some((payload, signature)) => {
            if verbose {
              eprint_line("object \{tag_id.to_hex()}")
              eprint_line("type tag")
              eprint_line("tag \{tag_name}")
            }
            if raw {
              ignore(signature)
            }
            let verified = signing_verify_payload(
              fs, root, git_dir, payload, signature,
            ) catch {
              err => {
                eprint_line(
                  "error: could not verify the tag '\{tag_name}': \{err}",
                )
                had_error = true
                continue
              }
            }
            if verified {
              match format {
                Some(value) =>
                  print_line(value.replace_all(old="%(tag)", new=tag_name))
                None => ()
              }
            } else {
              had_error = true
            }
          }
          None => {
            eprint_line("error: no signature found")
            had_error = true
          }
        }
      Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
        // Lightweight tag pointing to a commit - no signature possible
        eprint_line("error: no signature found")
        had_error = true
      }
      Some(_) => {
        eprint_line("error: \{tag_name}: cannot verify a non-tag object")
        had_error = true
      }
      None => {
        eprint_line("error: tag '\{tag_name}' not found.")
        had_error = true
      }
    }
  }
  if had_error {
    @sys.exit(1)
  }
}

///|
