///| Tests for `history reword` core (git 2.55 EXPERIMENTAL).
/// Runs on the js target against an in-memory host, mirroring
/// history_fixup_wbtest.mbt.

///|
fn hr_commit(host : Int, msg : String, ts : Int) -> String {
  match js_commit(host, "/repo", msg, "T <t@e.com>", ts) {
    Ok(id) => id
    Err(e) => abort("commit \{msg}: \{e}")
  }
}

///|
fn hr_write(host : Int, path : String, content : String) -> Unit {
  guard js_host_write_string(host, path, content) is Ok(_) else {
    abort("write \{path}")
  }
}

///|
fn hr_add(host : Int, paths : Array[String]) -> Unit {
  guard js_add_paths(host, "/repo", paths) is Ok(_) else { abort("add") }
}

///|
/// Run history_reword on `/repo` against `target_spec`, updating only the
/// `main` branch. Returns (result, fs, git_dir, db).
fn hr_run(
  host : Int,
  target_spec : String,
  new_message : String,
) -> (HistoryFixupResult, LibJsHostFs, String, ObjectDb) raise @bit.GitError {
  let fs = js_make_host_fs(host)
  let rfs : &@bit.RepoFileSystem = fs
  let ffs : &@bit.FileSystem = fs
  let git_dir = js_resolve_git_dir(fs, "/repo")
  let db = ObjectDb::load(rfs, git_dir)
  guard rev_parse(rfs, git_dir, "HEAD") is Some(head) else { abort("rev HEAD") }
  guard rev_parse(rfs, git_dir, target_spec) is Some(target) else {
    abort("rev \{target_spec}")
  }
  let (_, branches) = list_branches(rfs, git_dir)
  let mut main_tip = head
  for b in branches {
    if b.name == "main" {
      main_tip = b.id
    }
  }
  let tips : Array[HistoryRefUpdate] = [
    { refname: "refs/heads/main", old_id: main_tip, new_id: main_tip },
  ]
  let result = history_reword(db, ffs, rfs, git_dir, target, new_message, tips)
  (result, fs, git_dir, db)
}

///|
fn hr_commit_info(
  db : ObjectDb,
  fs : LibJsHostFs,
  commit : @bit.ObjectId,
) -> RebaseCommitInfo raise @bit.GitError {
  let rfs : &@bit.RepoFileSystem = fs
  rebase_parse_commit_full(db, rfs, commit)
}

///|
test "history reword: rewrite tip message, tree and identity preserved" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hr_write(host, "/repo/a.t", "a\n")
  hr_add(host, ["a.t"])
  let _c1 = hr_commit(host, "first", 1700000000)
  hr_write(host, "/repo/b.t", "b\n")
  hr_add(host, ["b.t"])
  let c2 = hr_commit(host, "old message", 1700000100)
  let (result, fs, _git_dir, db) = hr_run(host, "HEAD", "new message\n")
  assert_eq(result.updates.length(), 1)
  assert_eq(result.updates[0].refname, "refs/heads/main")
  assert_eq(result.updates[0].old_id.to_hex(), c2)
  let new_tip = result.updates[0].new_id
  let old_info = hr_commit_info(db, fs, result.updates[0].old_id)
  let new_info = hr_commit_info(db, fs, new_tip)
  // Message changed; everything else preserved.
  assert_eq(new_info.message, "new message\n")
  assert_eq(new_info.tree, old_info.tree)
  assert_eq(new_info.parents, old_info.parents)
  assert_eq(new_info.author, old_info.author)
  assert_eq(new_info.author_time, old_info.author_time)
  assert_eq(new_info.committer, old_info.committer)
  assert_eq(new_info.commit_time, old_info.commit_time)
  js_destroy_host(host)
}

///|
test "history reword: middle commit, descendant replayed with same tree" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hr_write(host, "/repo/a.t", "a\n")
  hr_add(host, ["a.t"])
  let _c1 = hr_commit(host, "first", 1700000000)
  hr_write(host, "/repo/b.t", "b\n")
  hr_add(host, ["b.t"])
  let c2 = hr_commit(host, "middle old", 1700000100)
  hr_write(host, "/repo/c.t", "c\n")
  hr_add(host, ["c.t"])
  let c3 = hr_commit(host, "third", 1700000200)
  let (result, fs, _git_dir, db) = hr_run(host, "HEAD~", "middle new\n")
  assert_eq(result.updates.length(), 1)
  let new_tip = result.updates[0].new_id
  // Tip is a rewritten commit: same message/tree as c3, new parent chain.
  assert_true(new_tip.to_hex() != c3)
  let old_tip_info = hr_commit_info(db, fs, @bit.ObjectId::from_hex(c3))
  let new_tip_info = hr_commit_info(db, fs, new_tip)
  assert_eq(new_tip_info.message, old_tip_info.message)
  assert_eq(new_tip_info.tree, old_tip_info.tree)
  // Its parent is the reworded middle commit.
  let new_mid = new_tip_info.parents[0]
  assert_true(new_mid.to_hex() != c2)
  let new_mid_info = hr_commit_info(db, fs, new_mid)
  let old_mid_info = hr_commit_info(db, fs, @bit.ObjectId::from_hex(c2))
  assert_eq(new_mid_info.message, "middle new\n")
  assert_eq(new_mid_info.tree, old_mid_info.tree)
  js_destroy_host(host)
}

///|
test "history reword: unchanged message is a no-op" {
  let host = js_create_memory_host()
  guard js_git_init(host, "/repo", "main") is Ok(_) else { abort("init") }
  hr_write(host, "/repo/a.t", "a\n")
  hr_add(host, ["a.t"])
  let _c1 = hr_commit(host, "first", 1700000000)
  // js_commit stores the message as given; reuse it verbatim.
  let head_msg_probe = {
    let fs = js_make_host_fs(host)
    let rfs : &@bit.RepoFileSystem = fs
    let git_dir = js_resolve_git_dir(fs, "/repo")
    let db = ObjectDb::load(rfs, git_dir)
    guard rev_parse(rfs, git_dir, "HEAD") is Some(head) else {
      abort("rev HEAD")
    }
    rebase_parse_commit_full(db, rfs, head).message
  }
  let (result, _fs, _git_dir, _db) = hr_run(host, "HEAD", head_msg_probe)
  // Identical content hashes to the identical commit: no ref updates.
  assert_eq(result.updates.length(), 0)
  js_destroy_host(host)
}
