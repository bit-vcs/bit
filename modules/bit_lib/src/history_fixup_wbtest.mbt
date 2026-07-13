///| Tests for `history fixup` core, mirroring third_party/git t3453 cases.
/// Runs on the js target against an in-memory host.

///|
fn hf_commit(host : Int, msg : String, ts : Int) -> String {
  match js_commit(host, "/repo", msg, "T <t@e.com>", ts) {
    Ok(id) => id
    Err(e) => abort("commit \{msg}: \{e}")
  }
}

///|
fn hf_write(host : Int, path : String, content : String) -> Unit {
  guard js_host_write_string(host, path, content) is Ok(_) else {
    abort("write \{path}")
  }
}

///|
/// Replicate the CLI's exact flow (index->tree, list_branches tips,
/// history_fixup) to find which step diverges from the direct-core wbtests.
test "history fixup: full CLI flow (tip) replicates end to end" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hf_write(host, "/repo/initial.t", "initial\n")
  hf_add(host, ["initial.t"])
  let _c1 = hf_commit(host, "initial", 1700000000)
  hf_write(host, "/repo/file.txt", "content\n")
  hf_add(host, ["file.txt"])
  let c2 = hf_commit(host, "add file", 1700000100)
  hf_write(host, "/repo/file.txt", "content\nfix\n")
  hf_add(host, ["file.txt"])

  let fs = js_make_host_fs(host)
  let rfs : &@bit.RepoFileSystem = fs
  let ffs : &@bit.FileSystem = fs
  let git_dir = js_resolve_git_dir(fs, "/repo")
  let db = ObjectDb::load(rfs, git_dir)

  // Step 1: index -> tree (staged detection).
  let entries = read_index_entries(rfs, git_dir)
  let index_tree = write_tree_from_index(ffs, rfs, git_dir, entries)
  guard rev_parse(rfs, git_dir, "HEAD") is Some(head) else { abort("rev HEAD") }
  let head_tree = history_commit_tree(db, rfs, head)
  if index_tree == head_tree {
    abort("STEP1: staged change not detected (index_tree == head_tree)")
  }
  if head.to_hex() != c2 {
    abort("STEP1b: HEAD != c2")
  }

  // Step 2: list_branches tips.
  let (head_ref, branches) = list_branches(rfs, git_dir)
  let head_branch = match head_ref {
    Branch(name) => name
    Detached(_) => abort("STEP2: HEAD detached, expected branch")
  }
  if head_branch != "main" {
    abort("STEP2b: head branch = \{head_branch}, want main")
  }
  let mut found_main = false
  for b in branches {
    if b.name == "main" {
      found_main = true
      if b.id != head {
        abort("STEP2c: main id \{b.id.to_hex()} != HEAD \{head.to_hex()}")
      }
    }
  }
  if !found_main {
    abort("STEP2d: main branch not in list_branches (\{branches.length()} branches)")
  }

  // Step 3: history_fixup produces an update for main.
  let tips : Array[HistoryRefUpdate] = [
    { refname: "refs/heads/main", old_id: head, new_id: head },
  ]
  let result = history_fixup(
    db, ffs, rfs, git_dir, head, index_tree, head, tips,
    HistoryEmptyAction::Drop, None,
  )
  if result.updates.length() != 1 {
    abort("STEP3: updates = \{result.updates.length()}, want 1")
  }
  let rewritten = result.updates[0].new_id
  // Step 4: rewritten commit carries the fix.
  let content = hf_file_content(db, fs, rewritten, "file.txt")
  if content != "content\nfix\n" {
    abort("STEP4: rewritten file.txt = \{content}")
  }
  js_destroy_host(host)
}

///|
fn hf_add(host : Int, paths : Array[String]) -> Unit {
  guard js_add_paths(host, "/repo", paths) is Ok(_) else { abort("add") }
}

///|
/// Run history_fixup on `/repo` folding the current index into `target_spec`,
/// updating only the `main` branch (HEAD). Returns (result, fs, git_dir, db).
fn hf_run(
  host : Int,
  target_spec : String,
  empty : HistoryEmptyAction,
) -> (HistoryFixupResult, LibJsHostFs, String, ObjectDb) raise @bit.GitError {
  let fs = js_make_host_fs(host)
  let rfs : &@bit.RepoFileSystem = fs
  let ffs : &@bit.FileSystem = fs
  let git_dir = js_resolve_git_dir(fs, "/repo")
  let db = ObjectDb::load(rfs, git_dir)
  let entries = read_index_entries(rfs, git_dir)
  let index_tree = write_tree_from_entries(ffs, rfs, git_dir, entries, None)
  guard rev_parse(rfs, git_dir, "HEAD") is Some(head) else { abort("rev HEAD") }
  guard rev_parse(rfs, git_dir, target_spec) is Some(target) else {
    abort("rev \{target_spec}")
  }
  let (_, main_id) = list_branches(rfs, git_dir)
  let mut main_tip = head
  for b in main_id {
    if b.name == "main" {
      main_tip = b.id
    }
  }
  let tips : Array[HistoryRefUpdate] = [
    { refname: "refs/heads/main", old_id: main_tip, new_id: main_tip },
  ]
  let result = history_fixup(
    db, ffs, rfs, git_dir, target, index_tree, head, tips, empty, None,
  )
  (result, fs, git_dir, db)
}

///|
fn hf_file_content(
  db : ObjectDb,
  fs : LibJsHostFs,
  commit : @bit.ObjectId,
  path : String,
) -> String raise @bit.GitError {
  let rfs : &@bit.RepoFileSystem = fs
  let tree = history_commit_tree(db, rfs, commit)
  let files = collect_tree_files(db, rfs, tree)
  match files.get(path) {
    Some(e) => merge_get_blob_text(db, rfs, e.id)
    None => abort("missing \{path}")
  }
}

///|
test "history fixup: fold staged change into the tip commit" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hf_write(host, "/repo/initial.t", "initial\n")
  hf_add(host, ["initial.t"])
  let _c1 = hf_commit(host, "initial", 1700000000)
  hf_write(host, "/repo/file.txt", "content\n")
  hf_add(host, ["file.txt"])
  let _c2 = hf_commit(host, "add file", 1700000100)
  // stage a fix
  hf_write(host, "/repo/file.txt", "content\nfix\n")
  hf_add(host, ["file.txt"])
  let (result, fs, _git_dir, db) = hf_run(host, "HEAD", Drop)
  // main should be updated to a rewritten tip
  assert_eq(result.updates.length(), 1)
  assert_eq(result.updates[0].refname, "refs/heads/main")
  let rewritten = result.updates[0].new_id
  assert_eq(hf_file_content(db, fs, rewritten, "file.txt"), "content\nfix\n")
  // initial.t is untouched
  assert_eq(hf_file_content(db, fs, rewritten, "initial.t"), "initial\n")
  js_destroy_host(host)
}

///|
test "history fixup: fold into a commit in the middle, replay descendant" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hf_write(host, "/repo/first.t", "first\n")
  hf_add(host, ["first.t"])
  let _c1 = hf_commit(host, "first", 1700000000)
  hf_write(host, "/repo/file.txt", "content\n")
  hf_add(host, ["file.txt"])
  let _c2 = hf_commit(host, "add file", 1700000100)
  hf_write(host, "/repo/third.t", "third\n")
  hf_add(host, ["third.t"])
  let _c3 = hf_commit(host, "third", 1700000200)
  // stage a fix to file.txt, fold into HEAD~ ("add file")
  hf_write(host, "/repo/file.txt", "content\nfix\n")
  hf_add(host, ["file.txt"])
  let (result, fs, git_dir, db) = hf_run(host, "HEAD~", Drop)
  assert_eq(result.updates.length(), 1)
  let new_tip = result.updates[0].new_id
  // The replayed tip (third) still has the change and third.t.
  assert_eq(hf_file_content(db, fs, new_tip, "file.txt"), "content\nfix\n")
  assert_eq(hf_file_content(db, fs, new_tip, "third.t"), "third\n")
  // And the middle commit (new_tip's parent) carries the fix directly.
  let rfs : &@bit.RepoFileSystem = fs
  let parent = rebase_parse_commit_full(db, rfs, new_tip).parents[0]
  ignore(git_dir)
  assert_eq(hf_file_content(db, fs, parent, "file.txt"), "content\nfix\n")
  js_destroy_host(host)
}

///|
test "history fixup: fold into the root commit" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hf_write(host, "/repo/root.txt", "initial\n")
  hf_add(host, ["root.txt"])
  let _c1 = hf_commit(host, "root", 1700000000)
  hf_write(host, "/repo/second.t", "second\n")
  hf_add(host, ["second.t"])
  let _c2 = hf_commit(host, "second", 1700000100)
  hf_write(host, "/repo/root.txt", "initial\nfix\n")
  hf_add(host, ["root.txt"])
  let (result, fs, _git_dir, db) = hf_run(host, "HEAD~", Drop)
  assert_eq(result.updates.length(), 1)
  let new_tip = result.updates[0].new_id
  let rfs : &@bit.RepoFileSystem = fs
  let root = rebase_parse_commit_full(db, rfs, new_tip).parents[0]
  assert_eq(hf_file_content(db, fs, root, "root.txt"), "initial\nfix\n")
  assert_eq(hf_file_content(db, fs, new_tip, "second.t"), "second\n")
  js_destroy_host(host)
}
