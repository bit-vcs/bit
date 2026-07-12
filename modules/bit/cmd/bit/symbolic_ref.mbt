///|
async fn handle_symbolic_ref(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut delete_mode = false
  let mut short_mode = false
  let mut recurse = true
  let mut message : String? = None
  let positional : Array[String] = []
  let mut ai = 0
  while ai < args.length() {
    let arg = args[ai]
    match arg {
      "-d" | "--delete" => delete_mode = true
      "--short" => short_mode = true
      "--recurse" => recurse = true
      "--no-recurse" => recurse = false
      "-m" if ai + 1 < args.length() => {
        message = Some(args[ai + 1])
        ai = ai + 1
      }
      _ if !arg.has_prefix("-") => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("symbolic-ref", arg)
      _ => ()
    }
    ai = ai + 1
  }
  if positional.length() == 0 {
    raise @bitcore.GitError::InvalidObject(
      "usage: git symbolic-ref <name> [<ref>]",
    )
  }
  let name = symbolic_ref_normalize_refname(positional[0])
  let ref_path = symbolic_ref_resolve_ref_path(fs, root, name)
  if delete_mode {
    // git refuses to delete HEAD outright.
    if name == "HEAD" {
      eprint_line("fatal: deleting 'HEAD' is not allowed")
      @sys.exit(128)
    }
    // Only symbolic refs may be deleted via symbolic-ref -d. A missing ref or
    // a regular (non-symbolic) ref is refused, and left untouched.
    let is_symbolic = if fs.is_file(ref_path) {
      decode_bytes(fs.read_file(ref_path))
      .trim_end(chars="\n\r ")
      .to_owned()
      .has_prefix("ref: ")
    } else {
      false
    }
    if !is_symbolic {
      eprint_line("fatal: Cannot delete \{name}, not a symbolic ref")
      @sys.exit(128)
    }
    fs.remove_file(ref_path)
    return ()
  }
  if positional.length() == 1 {
    // Read mode
    if !fs.is_file(ref_path) {
      raise @bitcore.GitError::InvalidObject("ref \{name} not found")
    }
    let content = decode_bytes(fs.read_file(ref_path))
    let trimmed = content.trim_end(chars="\n\r ").to_owned()
    if trimmed.has_prefix("ref: ") {
      let mut target = String::unsafe_substring(
        trimmed,
        start=5,
        end=trimmed.length(),
      )
      // By default git follows the symref chain to the final target; the last
      // ref in the chain that is itself a symref determines the output.
      // --no-recurse stops after the first level.
      if recurse {
        for _depth in 0..<10 {
          let tpath = symbolic_ref_resolve_ref_path(fs, root, target)
          if !fs.is_file(tpath) {
            break
          }
          let tcontent = decode_bytes(fs.read_file(tpath))
            .trim_end(chars="\n\r ")
            .to_owned()
          if tcontent.has_prefix("ref: ") {
            target = String::unsafe_substring(
              tcontent,
              start=5,
              end=tcontent.length(),
            )
          } else {
            break
          }
        }
      }
      if short_mode {
        print_line(symbolic_ref_shorten(target))
      } else {
        print_line(target)
      }
    } else {
      raise @bitcore.GitError::InvalidObject(
        "ref \{name} is not a symbolic ref",
      )
    }
  } else {
    // Write mode
    let target = symbolic_ref_normalize_refname(positional[1])
    let git_dir = resolve_git_dir(fs, root)
    // Capture the pre-update resolved value for the reflog (zero if unborn).
    let old_id = match @bitrepo.rev_parse(fs, git_dir, name) {
      Some(id) => id
      None => @bitcore.ObjectId::zero()
    }
    fs.write_string(ref_path, "ref: \{target}\n")
    // git records a reflog entry for the updated ref when given a reason (-m).
    match message {
      Some(msg) => {
        let rfs : &@bitcore.RepoFileSystem = fs
        let wfs : &@bitcore.FileSystem = fs
        let new_id = match @bitrepo.rev_parse(fs, git_dir, target) {
          Some(id) => id
          None => @bitcore.ObjectId::zero()
        }
        let timestamp = get_current_timestamp()
        let (author, email) = get_author_info(fs, git_dir)
        @bitrepo.append_reflog(
          wfs, rfs, git_dir, name, old_id, new_id, author, email, timestamp, "+0000",
          msg,
        )
      }
      None => ()
    }
  }
}

///|
fn symbolic_ref_resolve_ref_path(
  fs : &@bitcore.RepoFileSystem,
  root : String,
  name : String,
) -> String {
  let git_dir = resolve_git_dir(fs, root)
  if name == "HEAD" {
    normalize_path(git_dir + "/HEAD")
  } else {
    normalize_path(git_dir + "/" + name)
  }
}

///|
/// Shorten a ref name for `symbolic-ref --short`, mirroring git's prefix rules
/// (most specific / shortest result first):
///   refs/remotes/<x>/HEAD -> <x>, refs/heads/<x> -> <x>, refs/tags/<x> -> <x>,
///   refs/remotes/<x> -> <x>, refs/<x> -> <x>.
fn symbolic_ref_shorten(target : String) -> String {
  fn strip(prefix_len : Int) -> String {
    String::unsafe_substring(target, start=prefix_len, end=target.length())
  }

  if target.has_prefix("refs/remotes/") && target.has_suffix("/HEAD") {
    return String::unsafe_substring(target, start=13, end=target.length() - 5)
  }
  if target.has_prefix("refs/heads/") {
    return strip(11)
  }
  if target.has_prefix("refs/tags/") {
    return strip(10)
  }
  if target.has_prefix("refs/remotes/") {
    return strip(13)
  }
  if target.has_prefix("refs/") {
    return strip(5)
  }
  target
}

///|
fn symbolic_ref_normalize_refname(
  name : String,
) -> String raise @bitcore.GitError {
  let normalized = @bitlib.normalize_repo_path(name) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid refname: " + name)
  }
  // Accept HEAD, refs/..., and one-component root refs such as DANGLING_HEAD
  // (git allows symbolic-ref on these).
  if normalized == "HEAD" ||
    normalized.has_prefix("refs/") ||
    for_each_ref_is_root_ref_syntax(normalized) {
    normalized
  } else {
    raise @bitcore.GitError::InvalidObject("invalid refname: " + name)
  }
}

///|
test "symbolic-ref: normalize allows refs and HEAD" {
  assert_eq(symbolic_ref_normalize_refname("HEAD"), "HEAD")
  assert_eq(
    symbolic_ref_normalize_refname("refs/heads/main"),
    "refs/heads/main",
  )
}

///|
test "symbolic-ref: normalize rejects bare ref name" {
  let _ = symbolic_ref_normalize_refname("main") catch { _ => return () }
  assert_true(false)
}

///|
test "symbolic-ref: normalize rejects path traversal" {
  let _ = symbolic_ref_normalize_refname("../config") catch { _ => return () }
  assert_true(false)
}

///|
test "symbolic-ref: resolves HEAD through submodule gitdir file" {
  let fs = @bitcore.TestFs::new()
  fs.mkdir_p("/repo/.git/modules/sub/refs/heads")
  fs.write_string("/repo/sub/.git", "gitdir: ../.git/modules/sub\n")
  fs.write_string("/repo/.git/modules/sub/HEAD", "ref: refs/heads/main\n")
  let ref_path = symbolic_ref_resolve_ref_path(fs, "/repo/sub", "HEAD")
  assert_eq(ref_path, "/repo/.git/modules/sub/HEAD")
}

///|
