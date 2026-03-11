///|
async fn handle_symbolic_ref(args : Array[String]) -> Unit raise Error {
  let root = get_work_root()
  let fs = OsFs::new()
  let mut delete_mode = false
  let mut short_mode = false
  let positional : Array[String] = []
  for arg in args {
    match arg {
      "-d" | "--delete" => delete_mode = true
      "--short" => short_mode = true
      _ if not(arg.has_prefix("-")) => positional.push(arg)
      _ if arg.has_prefix("-") => warn_unimplemented_arg("symbolic-ref", arg)
      _ => ()
    }
  }
  if positional.length() == 0 {
    raise @bitcore.GitError::InvalidObject(
      "usage: git symbolic-ref <name> [<ref>]",
    )
  }
  let name = symbolic_ref_normalize_refname(positional[0])
  let ref_path = symbolic_ref_resolve_ref_path(fs, root, name)
  if delete_mode {
    if fs.is_file(ref_path) {
      fs.remove_file(ref_path)
    }
    return ()
  }
  if positional.length() == 1 {
    // Read mode
    if not(fs.is_file(ref_path)) {
      raise @bitcore.GitError::InvalidObject("ref \{name} not found")
    }
    let content = decode_bytes(fs.read_file(ref_path))
    let trimmed = content.trim_end(chars="\n\r ").to_string()
    if trimmed.has_prefix("ref: ") {
      let target = String::unsafe_substring(
        trimmed,
        start=5,
        end=trimmed.length(),
      )
      if short_mode && target.has_prefix("refs/heads/") {
        print_line(
          String::unsafe_substring(target, start=11, end=target.length()),
        )
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
    fs.write_string(ref_path, "ref: \{target}\n")
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
fn symbolic_ref_normalize_refname(
  name : String,
) -> String raise @bitcore.GitError {
  let normalized = @bitlib.normalize_repo_path(name) catch {
    _ => raise @bitcore.GitError::InvalidObject("invalid refname: " + name)
  }
  if normalized == "HEAD" || normalized.has_prefix("refs/") {
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
