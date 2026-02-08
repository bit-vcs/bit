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
  let new_id = @git.ObjectId::from_hex(
    "0123456789abcdef0123456789abcdef01234567",
  )
  let (flag, status) = classify_push_porcelain_success(
    @git.ObjectId::zero(),
    new_id,
    false,
    false,
  )
  assert_eq(flag, "*")
  assert_eq(status, "[new reference]")
}

///|
test "push porcelain: classify non-fast-forward update marker" {
  let old_id = @git.ObjectId::from_hex(
    "0123456789abcdef0123456789abcdef01234567",
  )
  let new_id = @git.ObjectId::from_hex(
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
  let fs = @git.TestFs::new()
  ignore(try? @gitlib.init_repo(fs, "/src", bare=true))
  ignore(try? @gitlib.init_repo(fs, "/dst", bare=true))
  let blob_id = @gitlib.write_loose_object(
    fs,
    "/src",
    @git.ObjectType::Blob,
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
  let tag_id = @gitlib.write_loose_object(
    fs,
    "/src",
    @git.ObjectType::Tag,
    tag_data,
  )
  let src_db = @gitlib.ObjectDb::load(fs, "/src")
  let transferred_object_ids : Map[String, Bool] = {}
  copy_wanted_object_graph(
    fs, fs, src_db, "/dst", tag_id, transferred_object_ids,
  ) catch {
    _ => fail("copy_wanted_object_graph failed")
  }
  let dst_db = @gitlib.ObjectDb::load(fs, "/dst")
  let copied_tag = dst_db.get(fs, tag_id) catch { _ => None }
  let copied_blob = dst_db.get(fs, blob_id) catch { _ => None }
  assert_true(copied_tag is Some(_))
  assert_true(copied_blob is Some(_))
}

///|
test "push delete: prune_empty_parent_dirs removes empty nested ref dirs" {
  let fs = @git.TestFs::new()
  fs.write_string(
    "/repo/.git/refs/heads/branch/conflict", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n",
  )
  @gitlib.remove_ref_path(fs, fs, "/repo/.git/refs/heads/branch/conflict")
  prune_empty_parent_dirs(
    fs, fs, "/repo/.git/refs/heads/branch/conflict", "/repo/.git/refs/heads",
  )
  assert_true(not(fs.is_dir("/repo/.git/refs/heads/branch")))
  assert_true(fs.is_dir("/repo/.git/refs/heads"))
}
