///|
test "signing: every signature header is stripped from the payload" {
  let commit = "tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904\n" +
    "author A <a@example.com> 1700000000 +0000\n" +
    "committer A <a@example.com> 1700000000 +0000\n" +
    "gpgsig -----BEGIN PGP SIGNATURE-----\n" +
    " first\n" +
    " -----END PGP SIGNATURE-----\n" +
    "gpgsig-sha256 -----BEGIN PGP SIGNATURE-----\n" +
    " second\n" +
    " -----END PGP SIGNATURE-----\n" +
    "gpgsig -----BEGIN PGP SIGNATURE-----\n" +
    " third\n" +
    " -----END PGP SIGNATURE-----\n" +
    "\n" +
    "message\n"
  let (payload, signature) = match
    signing_extract_commit_signature(@utf8.encode(commit)) {
    Some(pair) => pair
    None => fail("expected a signature")
  }
  @test.assert_eq(
    decode_bytes(payload),
    "tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904\n" +
    "author A <a@example.com> 1700000000 +0000\n" +
    "committer A <a@example.com> 1700000000 +0000\n" +
    "\n" +
    "message\n",
  )
  // The signature is the first header's, with continuation lines.
  assert_true(signature.contains("first"))
  assert_false(signature.contains("second"))
  assert_false(signature.contains("third"))
}

///|
test "hooks: approvals are stored in the git dir, not the worktree" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-hooks-approval-location-" +
    get_current_timestamp().to_string()
  let git_dir = resolve_git_dir(OsFs::new(), root)
  fs.mkdir_p(git_dir + "/hooks")
  fs.write_string(git_dir + "/hooks/post-checkout", "#!/bin/sh\necho hi\n")
  let rfs : &@bitcore.RepoFileSystem = fs
  let checksum = hooks_active_checksum(rfs, root, "post-checkout").unwrap_or("")
  // A repository can ship `.bit/hooks/.approved/*` in its worktree; it must
  // not count as an approval.
  fs.mkdir_p(root + "/.bit/hooks/.approved")
  fs.write_string(
    root + "/.bit/hooks/.approved/post-checkout.sha1",
    checksum + "\n",
  )
  assert_false(hooks_is_current_checksum_approved(rfs, root, "post-checkout"))
  hooks_write_approved_checksum(fs, fs, root, "post-checkout", checksum)
  assert_true(fs.is_file(git_dir + "/hooks/.approved/post-checkout.sha1"))
  assert_true(hooks_is_current_checksum_approved(rfs, root, "post-checkout"))
  cleanup_tree(fs, root)
}
