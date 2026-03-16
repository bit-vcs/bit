///| git verify-commit - verify GPG signature of commits

///|
async fn handle_verify_commit(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
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
        // Check for GPG/SSH signature in commit object
        let has_sig = text.find("-----BEGIN PGP SIGNATURE-----") is Some(_) ||
          text.find("-----BEGIN SSH SIGNATURE-----") is Some(_) ||
          text.find("gpgsig ") is Some(_) ||
          text.find("gpgsig-sha256 ") is Some(_)
        if has_sig {
          if raw {
            match verify_commit_extract_sig(text) {
              Some(sig) => print_str(sig)
              None => ()
            }
          }
          if verbose {
            let tree_val = verify_commit_extract_field(text, "tree")
            let author_val = verify_commit_extract_field(text, "author")
            let committer_val = verify_commit_extract_field(text, "committer")
            eprint_line("tree " + tree_val)
            eprint_line("author " + author_val)
            eprint_line("committer " + committer_val)
          }
          eprint_line(
            "error: could not verify the commit '" +
            commit_name +
            "': no GPG support",
          )
          had_error = true
        } else {
          eprint_line("error: no signature found")
          had_error = true
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
fn verify_commit_extract_sig(text : String) -> String? {
  // Look for gpgsig header
  match text.find("gpgsig ") {
    Some(start) => {
      // Find the end of the signature (line not starting with space after gpgsig)
      let sig_section = String::unsafe_substring(
        text,
        start~,
        end=text.length(),
      )
      let mut result = ""
      let mut first = true
      for line_view in sig_section.split("\n") {
        let line = line_view.to_string()
        if first {
          first = false
          if line.has_prefix("gpgsig ") {
            result = result +
              String::unsafe_substring(line, start=7, end=line.length()) +
              "\n"
          }
        } else if line.has_prefix(" ") {
          result = result +
            String::unsafe_substring(line, start=1, end=line.length()) +
            "\n"
        } else {
          break
        }
      }
      if result.length() > 0 {
        Some(result)
      } else {
        None
      }
    }
    None => None
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
