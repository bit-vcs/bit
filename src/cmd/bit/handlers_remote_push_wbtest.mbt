///|
fn restore_env_var_for_push_wbtest(name : String, prev : String?) -> Unit {
  match prev {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
fn setup_force_if_includes_push_wbtest_repo() -> @bitcore.TestFs {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitlib.init_repo(fs, "/repo"))
  fs
}

///|
test "push-delete-current: missing ref is allowed even when current branch is checked out" {
  let (rejected, warned) = push_delete_current_branch_policy(
    false,
    Some("/repo"),
    None,
  )
  assert_false(rejected)
  assert_false(warned)
}

///|
test "push-delete-current: warn mode warns without rejecting" {
  let (rejected, warned) = push_delete_current_branch_policy(
    true,
    Some("/repo"),
    Some("warn"),
  )
  assert_false(rejected)
  assert_true(warned)
}

///|
test "push-delete-current: default rejects existing checked-out branch" {
  let (rejected, warned) = push_delete_current_branch_policy(
    true,
    Some("/repo"),
    None,
  )
  assert_true(rejected)
  assert_false(warned)
}

///|
test "push-default: upstream uses configured tracking" {
  let plan = resolve_push_target_plan(
    None,
    None,
    "main",
    ["parent1", "parent2"],
    Some("parent1"),
    Some("refs/heads/foo"),
    Some("upstream"),
    None,
    false,
  )
  assert_eq(plan.remote_name, "parent1")
  assert_eq(plan.source_ref, "refs/heads/main")
  assert_eq(plan.dest_ref, "refs/heads/foo")
  assert_false(plan.auto_set_upstream)
}

///|
test "push-default: upstream rejects explicit non-upstream remote" {
  let _ = resolve_push_target_plan(
    Some("parent2"),
    None,
    "main",
    ["parent1", "parent2"],
    Some("parent1"),
    Some("refs/heads/foo"),
    Some("upstream"),
    None,
    false,
  ) catch {
    _ => return ()
  }
  fail("expected upstream mismatch error")
}

///|
test "push-default: current chooses origin when multiple remotes" {
  let plan = resolve_push_target_plan(
    None,
    None,
    "main",
    ["origin", "parent1"],
    None,
    None,
    Some("current"),
    None,
    false,
  )
  assert_eq(plan.remote_name, "origin")
  assert_eq(plan.dest_ref, "refs/heads/main")
}

///|
test "push-default: current chooses sole remote" {
  let plan = resolve_push_target_plan(
    None,
    None,
    "main",
    ["parent2"],
    None,
    None,
    Some("current"),
    None,
    false,
  )
  assert_eq(plan.remote_name, "parent2")
  assert_eq(plan.dest_ref, "refs/heads/main")
}

///|
test "push-default: simple requires same-name upstream" {
  let _ = resolve_push_target_plan(
    None,
    None,
    "main",
    ["parent1"],
    Some("parent1"),
    Some("refs/heads/foo"),
    Some("simple"),
    Some("parent1"),
    false,
  ) catch {
    _ => return ()
  }
  fail("expected simple mismatch error")
}

///|
test "push-default: simple triangular falls back to current" {
  let plan = resolve_push_target_plan(
    None,
    None,
    "main",
    ["parent1", "parent2"],
    Some("parent1"),
    Some("refs/heads/foo"),
    Some("simple"),
    Some("parent2"),
    false,
  )
  assert_eq(plan.remote_name, "parent2")
  assert_eq(plan.dest_ref, "refs/heads/main")
}

///|
test "push-default: autosetup enables new branch push" {
  let plan = resolve_push_target_plan(
    None,
    None,
    "new-branch",
    ["parent1"],
    Some("parent1"),
    None,
    Some("upstream"),
    None,
    true,
  )
  assert_eq(plan.remote_name, "parent1")
  assert_eq(plan.dest_ref, "refs/heads/new-branch")
  assert_true(plan.auto_set_upstream)
}

///|
test "push-default: upstream fails in triangular workflow" {
  let _ = resolve_push_target_plan(
    None,
    None,
    "main",
    ["parent1", "parent2"],
    Some("parent1"),
    Some("refs/heads/foo"),
    Some("upstream"),
    Some("parent2"),
    false,
  ) catch {
    _ => return ()
  }
  fail("expected triangular upstream failure")
}

///|
test "push-default: matching without upstream merge fails" {
  let _ = resolve_push_target_plan(
    None,
    None,
    "new-branch",
    ["parent1"],
    Some("parent1"),
    None,
    Some("matching"),
    None,
    false,
  ) catch {
    _ => return ()
  }
  fail("expected matching failure")
}

///|
test "push-default: colon refspec is treated as matching" {
  let plan = resolve_push_target_plan(
    Some("origin"),
    Some(":"),
    "main",
    ["origin"],
    Some("origin"),
    Some("refs/heads/main"),
    Some("matching"),
    None,
    false,
  )
  assert_eq(plan.remote_name, "origin")
  assert_eq(plan.source_ref, "refs/heads/main")
  assert_eq(plan.dest_ref, "refs/heads/main")
}

///|
test "push force-if-includes: branch reflog allows local rebase rewrite" {
  let fs = setup_force_if_includes_push_wbtest_repo()
  fs.write_string("/repo/a.txt", "A\n")
  @bitlib.add_paths(fs, fs, "/repo", ["a.txt"])
  let commit_a = @bitlib.commit(
    fs, fs, "/repo", "A", "Test <test@example.com>", 1700000000L,
  )

  fs.write_string("/repo/b.txt", "B\n")
  @bitlib.add_paths(fs, fs, "/repo", ["b.txt"])
  let commit_b = @bitlib.commit(
    fs, fs, "/repo", "B", "Test <test@example.com>", 1700000001L,
  )

  fs.write_string("/repo/c.txt", "C\n")
  @bitlib.add_paths(fs, fs, "/repo", ["c.txt"])
  let commit_c = @bitlib.commit(
    fs, fs, "/repo", "C", "Test <test@example.com>", 1700000002L,
  )

  @bitlib.create_branch_at(fs, fs, "/repo", "rewritten", commit_a)
  @bitlib.switch_branch(fs, fs, "/repo", "rewritten", checkout_files=true)
  fs.write_string("/repo/d.txt", "D\n")
  @bitlib.add_paths(fs, fs, "/repo", ["d.txt"])
  let commit_d = @bitlib.commit(
    fs, fs, "/repo", "D", "Test <test@example.com>", 1700000003L,
  )

  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string("/repo/.git/refs/heads/main", commit_d.to_hex() + "\n")
  @bitrepo.append_reflog(
    fs, fs, "/repo/.git", "refs/heads/main", commit_c, commit_d, "Test", "test@example.com",
    1700000004L, "+0000", "rebase finished: refs/heads/main onto rewritten",
  )

  let db = @bitlib.ObjectDb::load(fs, "/repo/.git")
  assert_true(
    push_force_if_includes_satisfied(
      fs,
      db,
      "/repo/.git",
      "refs/heads/main",
      Some(commit_b),
    ),
  )
}

///|
test "push matching-refspec: fails when no branch candidates exist" {
  let parsed = parse_push_refspecs_with_presence([":"])
  let _ = ensure_matching_refspec_has_candidates(parsed, 0) catch {
    _ => return ()
  }
  fail("expected matching-refspec failure without candidates")
}

///|
test "push matching-refspec: allows at least one candidate" {
  let parsed = parse_push_refspecs_with_presence([":"])
  ensure_matching_refspec_has_candidates(parsed, 1)
}

///|
test "push-mirror: explicit option uses wildcard refspec" {
  let specs = push_resolve_mirror_refspecs(true, false, 0, false, false, false)
  assert_eq(specs, Some(["+refs/*:refs/*"]))
}

///|
test "push-mirror: remote config enables wildcard refspec" {
  let specs = push_resolve_mirror_refspecs(false, true, 0, false, false, false)
  assert_eq(specs, Some(["+refs/*:refs/*"]))
}

///|
test "push-mirror: mirrored remote rejects explicit refspec" {
  let _ = push_resolve_mirror_refspecs(false, true, 1, false, false, false) catch {
    _ => return ()
  }
  fail("expected mirror refspec conflict")
}

///|
test "push-parse: two positional args treat first as remote" {
  let (remote, refspec) = resolve_push_positionals(["", "main"], fn(_name) {
    false
  })
  assert_eq(remote, Some(""))
  assert_eq(refspec, Some("main"))
}

///|
test "push-parse: multi positionals keep all refspecs after remote" {
  let (remote, refspecs) = resolve_push_positionals_multi(
    ["origin", "main", "topic:topic"],
    fn(_name) { false },
  )
  assert_eq(remote, Some("origin"))
  assert_eq(refspecs.length(), 2)
  assert_eq(refspecs[0], "main")
  assert_eq(refspecs[1], "topic:topic")
}

///|
test "push-parse: single positional known remote" {
  let (remote, refspec) = resolve_push_positionals(["origin"], fn(name) {
    name == "origin"
  })
  assert_eq(remote, Some("origin"))
  assert_eq(refspec, None)
}

///|
test "push-parse: single positional unknown is refspec" {
  let (remote, refspec) = resolve_push_positionals(["main"], fn(_name) { false })
  assert_eq(remote, None)
  assert_eq(refspec, Some("main"))
}

///|
test "push-refspec: detect ambiguous short source token" {
  assert_true(is_ambiguous_push_source_refspec("foo", true, true))
}

///|
test "push-refspec: ignore head and rev-expression tokens" {
  assert_false(is_ambiguous_push_source_refspec("HEAD", true, true))
  assert_false(is_ambiguous_push_source_refspec("main~2", true, true))
}

///|
test "push/fetch options: strip long option prefix for error messages" {
  assert_eq(option_name_without_prefix("--no-ipv4"), "no-ipv4")
  assert_eq(option_name_without_prefix("--no-ipv6"), "no-ipv6")
}

///|
test "push relay: remote detection handles explicit relay schemes" {
  assert_true(push_remote_uses_relay_signaling("relay+http://127.0.0.1:8788"))
  assert_true(
    push_remote_uses_relay_signaling("relay+https://relay.example.com"),
  )
  assert_true(push_remote_uses_relay_signaling("relay://relay.example.com"))
  assert_false(
    push_remote_uses_relay_signaling("https://relay.example.com/repo.git"),
  )
  assert_false(
    push_remote_uses_relay_signaling("git@github.com:mizchi/bit.git"),
  )
}

///|
test "push relay: preferred sender/repo env is trimmed and optional" {
  let prev_sender = @sys.get_env_var("BIT_RELAY_PUSH_SENDER")
  let prev_repo = @sys.get_env_var("BIT_RELAY_PUSH_REPO")
  @sys.set_env_var("BIT_RELAY_PUSH_SENDER", " node-a ")
  @sys.set_env_var("BIT_RELAY_PUSH_REPO", " repo-b ")
  assert_eq(push_relay_preferred_sender(), Some("node-a"))
  assert_eq(push_relay_preferred_repo(), Some("repo-b"))
  @sys.set_env_var("BIT_RELAY_PUSH_SENDER", "   ")
  @sys.set_env_var("BIT_RELAY_PUSH_REPO", "   ")
  assert_eq(push_relay_preferred_sender(), None)
  assert_eq(push_relay_preferred_repo(), None)
  restore_env_var_for_push_wbtest("BIT_RELAY_PUSH_SENDER", prev_sender)
  restore_env_var_for_push_wbtest("BIT_RELAY_PUSH_REPO", prev_repo)
}

///|
test "push relay: sender filter is preferred over repo filter" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo-a.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo-b.git", Some("repo-b")),
  ]
  let selected = push_select_relay_peer(
    peers,
    preferred_sender=Some("node-a"),
    preferred_repo=Some("repo-b"),
  )
  assert_eq(selected, Some(("node-a", "http://node-a:9418/repo-a.git")))
}

///|
test "push relay: falls back to repo and then first peer" {
  let peers : Array[(String, String, String?)] = [
    ("node-a", "http://node-a:9418/repo-a.git", Some("repo-a")),
    ("node-b", "http://node-b:9418/repo-b.git", Some("repo-b")),
  ]
  let by_repo = push_select_relay_peer(
    peers,
    preferred_sender=Some("node-z"),
    preferred_repo=Some("repo-b"),
  )
  assert_eq(by_repo, Some(("node-b", "http://node-b:9418/repo-b.git")))
  let first = push_select_relay_peer(
    peers,
    preferred_sender=None,
    preferred_repo=Some("repo-z"),
  )
  assert_eq(first, Some(("node-a", "http://node-a:9418/repo-a.git")))
}

///|
test "url rewrite: insteadOf is applied for fetch/push" {
  let rules : Array[(String, String, Bool)] = [("/tmp/trash/", "trash/", false)]
  assert_eq(
    rewrite_url_by_rules("trash/testrepo", rules, false),
    "/tmp/trash/testrepo",
  )
  assert_eq(
    rewrite_url_by_rules("trash/testrepo", rules, true),
    "/tmp/trash/testrepo",
  )
}

///|
test "url rewrite: pushInsteadOf is push-only" {
  let rules : Array[(String, String, Bool)] = [("/tmp/trash/", "trash/", true)]
  assert_eq(
    rewrite_url_by_rules("trash/testrepo", rules, false),
    "trash/testrepo",
  )
  assert_eq(
    rewrite_url_by_rules("trash/testrepo", rules, true),
    "/tmp/trash/testrepo",
  )
}

///|
test "push normalize: source '@' maps to HEAD" {
  assert_eq(normalize_push_ref_token("@", "main", false), "HEAD")
}

///|
test "push normalize: source object id stays as-is" {
  let oid = "0123456789abcdef0123456789abcdef01234567"
  assert_eq(normalize_push_ref_token(oid, "main", false), oid)
}

///|
test "push plan: object id to incomplete destination is rejected" {
  let _ = resolve_push_target_plan(
    Some("origin"),
    "0123456789abcdef0123456789abcdef01234567:foo" |> Some,
    "main",
    ["origin"],
    Some("origin"),
    Some("refs/heads/main"),
    Some("simple"),
    None,
    false,
  ) catch {
    _ => return ()
  }
  fail("expected oid destination inference failure")
}

///|
test "push porcelain: line format matches git style" {
  let line = format_push_porcelain_line(
    "*", "refs/heads/main", "refs/remotes/origin/main", "[new reference]",
  )
  assert_eq(
    line, "*\trefs/heads/main:refs/remotes/origin/main\t[new reference]",
  )
}

///|
test "push porcelain: classify new reference" {
  let new_id = @bitcore.ObjectId::from_hex(
    "0123456789abcdef0123456789abcdef01234567",
  )
  let (flag, status) = classify_push_porcelain_success(
    @bitcore.ObjectId::zero(),
    new_id,
    false,
    false,
  )
  assert_eq(flag, "*")
  assert_eq(status, "[new reference]")
}

///|
test "push porcelain: classify non-fast-forward update marker" {
  let old_id = @bitcore.ObjectId::from_hex(
    "0123456789abcdef0123456789abcdef01234567",
  )
  let new_id = @bitcore.ObjectId::from_hex(
    "fedcba9876543210fedcba9876543210fedcba98",
  )
  let (flag, status) = classify_push_porcelain_success(
    old_id, new_id, false, false,
  )
  assert_eq(flag, " ")
  assert_eq(status, "[updated]")
}

///|
test "push reject: non-fast-forward takes precedence over deny-current-branch" {
  let status = select_push_rejection_status(true, false, true, false)
  assert_eq(status, Some("[rejected] (non-fast-forward)"))
}

///|
test "push hide-ref: prefix pattern matches nested refs" {
  assert_true(is_hidden_ref("refs/hidden/one", ["refs/hidden"]))
  assert_false(is_hidden_ref("refs/heads/main", ["refs/hidden"]))
}

///|
test "push prune: destination wildcard maps back to source wildcard" {
  let src = prune_source_ref_for_destination(
    "refs/heads/*", "refs/tmp/*", "refs/tmp/topic",
  )
  assert_eq(src, Some("refs/heads/topic"))
}

///|
test "fetch refspec: short source expands to branch and tag namespaces" {
  let candidates = fetch_source_candidates("main")
  assert_eq(candidates.length(), 3)
  assert_eq(candidates[0], "main")
  assert_eq(candidates[1], "refs/heads/main")
  assert_eq(candidates[2], "refs/tags/main")
}

///|
test "push refspec parse: keeps explicit destination presence" {
  let specs = parse_push_refspecs_with_presence([
    "main", "topic:refs/heads/topic", "+dev",
  ])
  assert_eq(specs.length(), 3)
  assert_false(specs[0].has_explicit_destination)
  assert_true(specs[1].has_explicit_destination)
  assert_false(specs[2].has_explicit_destination)
}

///|
test "push refmap: colon-less source uses remote.push refmap first" {
  let dst = infer_colonless_push_destination_token(
    "main",
    "refs/heads/main",
    PushSourceKind::Branch,
    "main",
    PushDefaultMode::Simple,
    Some("refs/heads/main"),
    ["+refs/heads/*:refs/remotes/src/*"],
  )
  assert_eq(dst, "refs/remotes/src/main")
}

///|
test "push refmap: without remote.push, upstream mapping is used" {
  let dst = infer_colonless_push_destination_token(
    "main",
    "refs/heads/main",
    PushSourceKind::Branch,
    "main",
    PushDefaultMode::Upstream,
    Some("refs/heads/trunk"),
    [],
  )
  assert_eq(dst, "refs/heads/trunk")
}

///|
test "push deny-current: updateInstead returns checked-out worktree path" {
  let decision = enforce_receive_deny_current_branch(
    Some("updateinstead"),
    Some("/repo/wt"),
    "refs/heads/main",
  )
  match decision {
    DenyCurrentBranchDecision::UpdateInstead(path) =>
      assert_eq(path, "/repo/wt")
    _ => fail("expected updateInstead decision")
  }
}

///|
test "push deny-current: refuse rejects checked-out branch" {
  let _ = enforce_receive_deny_current_branch(
    Some("refuse"),
    Some("/repo/wt"),
    "refs/heads/main",
  ) catch {
    _ => return ()
  }
  fail("expected checked-out branch rejection")
}

///|
test "push deny-current: no checked-out worktree allows update" {
  let decision = enforce_receive_deny_current_branch(
    Some("refuse"),
    None,
    "refs/heads/main",
  )
  match decision {
    DenyCurrentBranchDecision::Allow => ()
    _ => fail("expected allow decision in bare repository")
  }
}

///|
test "push transfer: tag that points to blob copies tagged blob object" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitrepo.init_repo(fs, "/src", bare=true))
  ignore(try? @bitrepo.init_repo(fs, "/dst", bare=true))
  let blob_id = @bitlib.write_loose_object(
    fs,
    "/src",
    @bitcore.ObjectType::Blob,
    str_to_bytes("unreferenced\n"),
  )
  let tag_data = str_to_bytes(
    "object " +
    blob_id.to_hex() +
    "\n" +
    "type blob\n" +
    "tag tag-of-blob\n" +
    "tagger Test User <test@example.com> 0 +0000\n" +
    "\n" +
    "foo\n",
  )
  let tag_id = @bitlib.write_loose_object(
    fs,
    "/src",
    @bitcore.ObjectType::Tag,
    tag_data,
  )
  let src_db = @bitlib.ObjectDb::load(fs, "/src")
  let transferred_object_ids : Map[String, Bool] = {}
  copy_wanted_object_graph(
    fs, fs, src_db, "/dst", tag_id, transferred_object_ids,
  ) catch {
    _ => fail("copy_wanted_object_graph failed")
  }
  let dst_db = @bitlib.ObjectDb::load(fs, "/dst")
  let copied_tag = dst_db.get(fs, tag_id) catch { _ => None }
  let copied_blob = dst_db.get(fs, blob_id) catch { _ => None }
  assert_true(copied_tag is Some(_))
  assert_true(copied_blob is Some(_))
}

///|
test "push transfer: alternates avoid copying reachable parent commits" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitrepo.init_repo(fs, "/src"))
  ignore(try? @bitrepo.init_repo(fs, "/alt", bare=true))
  ignore(try? @bitrepo.init_repo(fs, "/dst", bare=true))
  fs.write_string("/src/file", "one\n")
  @bitlib.add_paths(fs, fs, "/src", ["file"])
  let first = @bitlib.commit(
    fs, fs, "/src", "first\n", "Test <test@example.com>", 1700000000L,
  )
  fs.write_string("/src/file", "two\n")
  @bitlib.add_paths(fs, fs, "/src", ["file"])
  let second = @bitlib.commit(
    fs, fs, "/src", "second\n", "Test <test@example.com>", 1700000001L,
  )
  let src_db = @bitlib.ObjectDb::load(fs, "/src/.git")
  let warmup_ids : Map[String, Bool] = {}
  copy_wanted_object_graph(fs, fs, src_db, "/alt", first, warmup_ids) catch {
    _ => fail("copy_wanted_object_graph warmup failed")
  }
  fs.mkdir_p("/dst/objects/info")
  fs.write_string("/dst/objects/info/alternates", "../../alt/objects\n")
  let transferred_object_ids : Map[String, Bool] = {}
  copy_wanted_object_graph(
    fs, fs, src_db, "/dst", second, transferred_object_ids,
  ) catch {
    _ => fail("copy_wanted_object_graph failed")
  }
  fs.remove_file("/dst/objects/info/alternates")
  let dst_db = @bitlib.ObjectDb::load(fs, "/dst")
  let copied_second = dst_db.get(fs, second) catch { _ => None }
  let copied_first = dst_db.get(fs, first) catch { _ => None }
  assert_true(copied_second is Some(_))
  assert_true(copied_first is None)
}

///|
test "push delete: prune_empty_parent_dirs removes empty nested ref dirs" {
  let fs = @bitcore.TestFs::new()
  fs.write_string(
    "/repo/.git/refs/heads/branch/conflict", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  @bitlib.remove_ref_path(fs, fs, "/repo/.git/refs/heads/branch/conflict")
  prune_empty_parent_dirs(
    fs, fs, "/repo/.git/refs/heads/branch/conflict", "/repo/.git/refs/heads",
  )
  assert_true(!fs.is_dir("/repo/.git/refs/heads/branch"))
  assert_true(fs.is_dir("/repo/.git/refs/heads"))
}

///|
test "push-upstream: explicit source branch updates that branch config" {
  let updates : Array[PushUpstreamConfigUpdate] = []
  push_append_upstream_config_update(
    updates, "refs/heads/topic_2", "refs/heads/other2", "main", false,
  )
  assert_eq(updates.length(), 1)
  assert_eq(updates[0].branch_name, "topic_2")
  assert_eq(updates[0].merge_ref, "refs/heads/other2")
}

///|
test "push-upstream: HEAD maps to current branch" {
  let updates : Array[PushUpstreamConfigUpdate] = []
  push_append_upstream_config_update(
    updates, "HEAD", "refs/heads/headbranch", "headbranch", false,
  )
  assert_eq(updates.length(), 1)
  assert_eq(updates[0].branch_name, "headbranch")
  assert_eq(updates[0].merge_ref, "refs/heads/headbranch")
}

///|
test "push-upstream: delete refs do not update tracking config" {
  let updates : Array[PushUpstreamConfigUpdate] = []
  push_append_upstream_config_update(
    updates, "refs/heads/topic_2", "refs/heads/topic_2", "main", true,
  )
  assert_eq(updates.length(), 0)
}

///|
test "push-progress: quiet and no-progress suppress output" {
  assert_true(push_should_emit_progress(Some(true), false))
  assert_false(push_should_emit_progress(Some(false), false))
  assert_false(push_should_emit_progress(Some(true), true))
}

///|
test "push-lease: parse empty explicit expectation" {
  let fs = @bitcore.TestFs::new()
  ignore(try? @bitrepo.init_repo(fs, "/repo"))
  let (refname, expectation) = push_parse_force_with_lease_value(
    fs, "/repo/.git", "branch:",
  )
  assert_eq(refname, "refs/heads/branch")
  match expectation {
    PushLeaseExpectation::Explicit(None) => ()
    _ => fail("expected explicit empty lease expectation")
  }
}

///|
test "push-lease: remote tracking refname follows pushed remote" {
  assert_eq(
    push_remote_tracking_refname("origin-push", "refs/heads/main"),
    Some("refs/remotes/origin-push/main"),
  )
  assert_eq(push_remote_tracking_refname("origin", "refs/tags/v1"), None)
}
