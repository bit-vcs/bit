///| Helpers for running git as an oracle in native tests

///|
fn cleanup_temp_files(paths : Array[String]) -> Unit {
  for path in paths {
    if @fs.path_exists(path) {
      @fs.remove_file(path) catch {
        _ => ()
      }
    }
  }
}

///|
fn ensure_dir(path : String) -> Unit {
  if not(@fs.path_exists(path)) {
    @fs.create_dir(path) catch {
      _ => ()
    }
  }
}

///|
fn oracle_base_dir() -> String {
  ensure_dir("target")
  ensure_dir("target/git-oracle")
  "target/git-oracle"
}

///|
async fn run_git(
  args : Array[String],
  stdin_data : Bytes?,
  cwd : String?,
) -> (Int, Bytes, Bytes) {
  let nonce = @async.now()
  let base_dir = oracle_base_dir()
  let base = "\{base_dir}/run-\{nonce}"
  let stdout_path = "\{base}.out"
  let stderr_path = "\{base}.err"
  let stdin_path = "\{base}.in"
  let stdout = @process.redirect_to_file(stdout_path, truncate=true, create=420)
  let stderr = @process.redirect_to_file(stderr_path, truncate=true, create=420)
  let stdin = match stdin_data {
    None => None
    Some(data) => {
      @fs.write_bytes_to_file(stdin_path, data) catch {
        _ => ()
      }
      Some(@process.redirect_from_file(stdin_path))
    }
  }
  let code = match cwd {
    None =>
      match stdin {
        None => @process.run("git", args, inherit_env=true, stdout~, stderr~)
        Some(input) =>
          @process.run(
            "git",
            args,
            inherit_env=true,
            stdin=input,
            stdout~,
            stderr~,
          )
      }
    Some(dir) =>
      match stdin {
        None =>
          @process.run("git", args, inherit_env=true, stdout~, stderr~, cwd=dir)
        Some(input) =>
          @process.run(
            "git",
            args,
            inherit_env=true,
            stdin=input,
            stdout~,
            stderr~,
            cwd=dir,
          )
      }
  }
  let out = @fs.read_file_to_bytes(stdout_path) catch { _ => Bytes::default() }
  let err = @fs.read_file_to_bytes(stderr_path) catch { _ => Bytes::default() }
  cleanup_temp_files([stdout_path, stderr_path, stdin_path])
  (code, out, err)
}

///|
fn bytes_to_string_lossy(data : Bytes) -> String {
  @utf8.decode_lossy(data[:])
}

///|
fn first_line(text : String) -> String {
  match String::split(text, "\n").head() {
    None => ""
    Some(line) => line.to_string()
  }
}

///|
fn first_word(text : String) -> String {
  match String::split(text, " ").head() {
    None => ""
    Some(word) => word.to_string()
  }
}

///|
fn contains_string(xs : Array[String], value : String) -> Bool {
  for item in xs {
    if item == value {
      return true
    }
  }
  false
}

///|
fn create_temp_dir(prefix : String) -> String {
  let nonce = @async.now()
  let base_dir = oracle_base_dir()
  let path = "\{base_dir}/\{prefix}-\{nonce}"
  @fs.create_dir(path) catch {
    _ => ()
  }
  path
}

///|
async fn remove_dir_recursive(path : String) -> Unit {
  ignore(@process.run("rm", ["-rf", path], inherit_env=true))
}

///|
async fn git_stdout_trim(args : Array[String], cwd : String?) -> (Int, String) {
  let (code, out, _) = run_git(args, None, cwd)
  (code, String::trim(bytes_to_string_lossy(out)).to_string())
}

///|
async test "git oracle: index-pack accepts blob packfile" {
  let temp_dir = create_temp_dir("moonbit-git-pack-oracle")
  let content = @utf8.encode("hello\n")
  let packfile = create_blob_packfile(content)
  let pack_path = "\{temp_dir}/test.pack"
  let idx_path = "\{temp_dir}/test.idx"
  @fs.write_bytes_to_file(pack_path, packfile) catch {
    _ => assert_true(false)
  }
  let (code, _, _) = run_git(
    ["index-pack", "-o", idx_path, pack_path],
    None,
    None,
  )
  assert_true(code == 0)
  assert_true(@fs.path_exists(idx_path))
  let (vcode, vout, _) = run_git(["verify-pack", "-v", pack_path], None, None)
  assert_true(vcode == 0)
  let expected = hash_blob(content).to_hex()
  let line = first_line(bytes_to_string_lossy(vout))
  let oid = first_word(line)
  assert_true(oid == expected)
  remove_dir_recursive(temp_dir)
}

///|
async test "git oracle: parse pack-objects output" {
  let repo_dir = create_temp_dir("moonbit-git-pack-repo")
  let content = @utf8.encode("hello\n")
  @fs.write_bytes_to_file("\{repo_dir}/hello.txt", content) catch {
    _ => assert_true(false)
  }
  let (init_code, _, _) = run_git(["init"], None, Some(repo_dir))
  assert_true(init_code == 0)
  let (add_code, _, _) = run_git(["add", "hello.txt"], None, Some(repo_dir))
  assert_true(add_code == 0)
  let (commit_code, _, _) = run_git(
    [
      "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m",
      "init",
    ],
    None,
    Some(repo_dir),
  )
  assert_true(commit_code == 0)
  let (pack_code, pack_out, _) = run_git(
    ["pack-objects", "--stdout", "--revs"],
    Some(@utf8.encode("HEAD\n")),
    Some(repo_dir),
  )
  assert_true(pack_code == 0)
  let objects = try parse_packfile(pack_out) catch {
    _ => {
      assert_true(false)
      []
    }
  } noraise {
    v => v
  }
  let parsed_ids : Array[String] = []
  for obj in objects {
    parsed_ids.push(hash_object_content(obj.obj_type, obj.data).to_hex())
  }
  let (commit_code, commit_hex) = git_stdout_trim(
    ["rev-parse", "HEAD"],
    Some(repo_dir),
  )
  assert_true(commit_code == 0)
  let (tree_code, tree_hex) = git_stdout_trim(
    ["rev-parse", "HEAD^{tree}"],
    Some(repo_dir),
  )
  assert_true(tree_code == 0)
  let (blob_code, blob_hex) = git_stdout_trim(
    ["hash-object", "hello.txt"],
    Some(repo_dir),
  )
  assert_true(blob_code == 0)
  assert_true(contains_string(parsed_ids, commit_hex))
  assert_true(contains_string(parsed_ids, tree_hex))
  assert_true(contains_string(parsed_ids, blob_hex))
  remove_dir_recursive(repo_dir)
}
