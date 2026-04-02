///| git verify-commit - verify GPG signature of commits

///|
async fn handle_verify_commit(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let root = get_work_root()
  let git_dir = find_git_dir(fs)
  let mut verbose = false
  let mut raw = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-v" | "--verbose" => verbose = true
      "--raw" => raw = true
      "-h" | "--help" => {
        show_simple_command_help(
          "git verify-commit [-v | --verbose] [--raw] <commit>...",
          summary="Verify the GPG signature of commits.",
        )
        return
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("verify-commit", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  if positional.length() == 0 {
    eprint_line("usage: git verify-commit [-v | --verbose] [--raw] <commit>...")
    @sys.exit(1)
    return
  }
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  let mut had_error = false
  for commit_name in positional {
    // Resolve the commit reference
    let commit_id = match @bitrepo.rev_parse(fs, git_dir, commit_name) {
      Some(id) => id
      None => {
        eprint_line("error: object " + commit_name + " is a non-commit object.")
        had_error = true
        continue
      }
    }
    // Get the object
    match db.get(fs, commit_id) {
      Some(obj) if obj.obj_type == @bitcore.ObjectType::Commit => {
        let text = decode_bytes(obj.data)
        match signing_extract_commit_signature(obj.data) {
          Some((payload, signature)) => {
            if verbose {
              let tree_val = verify_commit_extract_field(text, "tree")
              let author_val = verify_commit_extract_field(text, "author")
              let committer_val = verify_commit_extract_field(text, "committer")
              eprint_line("tree " + tree_val)
              eprint_line("author " + author_val)
              eprint_line("committer " + committer_val)
            }
            if raw {
              ignore(signature)
            }
            let verified = signing_verify_payload(
              fs, root, git_dir, payload, signature,
            ) catch {
              err => {
                eprint_line(
                  "error: could not verify the commit '" +
                  commit_name +
                  "': \{err}",
                )
                had_error = true
                continue
              }
            }
            if !verified {
              had_error = true
            }
          }
          None => {
            eprint_line("error: no signature found")
            had_error = true
          }
        }
      }
      Some(_) => {
        eprint_line("error: object " + commit_name + " is a non-commit object.")
        had_error = true
      }
      None => {
        eprint_line("error: object " + commit_name + " not found.")
        had_error = true
      }
    }
  }
  if had_error {
    @sys.exit(1)
  }
}

///|
fn verify_commit_extract_field(text : String, field : String) -> String {
  let prefix = field + " "
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.has_prefix(prefix) {
      return String::unsafe_substring(
        line,
        start=prefix.length(),
        end=line.length(),
      )
    }
  }
  ""
}
