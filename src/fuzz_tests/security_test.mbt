///| Adversarial / security regression tests.
///
/// These tests pin known sharp edges so a fix or accidental regression
/// is loud. Each test starts from raw bytes (or a constructed tree)
/// and walks through the parser/normalizer to show where validation is
/// missing.

///|
/// Build a tree payload (raw, no object header) containing a single
/// entry with the given name and mode. Useful for round-tripping
/// through @bit.parse_tree.
fn make_tree_payload_with_name(
  mode : String,
  name : String,
  blob_id : @bit.ObjectId,
) -> Bytes {
  let entry = @bit.TreeEntry::new(mode, name, blob_id)
  @bit.serialize_tree([entry])
}

///|
/// Demonstrates: bit's `@bit.parse_tree` accepts an `entry.name`
/// containing `../` traversal. The parser only stops the name field at
/// NUL; the slash and dot bytes are accepted verbatim.
///
/// On a real OS-backed FileSystem, the entry name flows through
/// `collect_tree_files` (concat with `prefix + "/" + entry.name`) and
/// then `join_path(root, path)` + `fs.write_file(...)`. Since neither
/// of those normalizes the path, a clone or checkout of an
/// attacker-controlled repository can write the blob outside the
/// worktree.
///
/// When/if a tree-entry validator lands (matching git's
/// `verify_path()`), this assertion should be inverted to expect a
/// raised GitError. The expected rejection rules are: name must not be
/// empty, must not be `.` / `..`, must not contain `/` or `\0`, and
/// must not be `.git` case-insensitively.
test "security: parse_tree accepts entry name '../escape' (no verify_path equivalent)" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", "../escape", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].name, "../escape")
}

///|
/// Same root cause, different surface: a tree entry whose name *is*
/// the literal string `.git/hooks/post-checkout`. The slash is
/// preserved verbatim, so a writer that joins it with the worktree
/// root drops a hook into `.git/hooks/`.
test "security: parse_tree accepts entry name '.git/hooks/post-checkout'" {
  let blob_id = @bit.hash_blob(b"#!/bin/sh\nrm -rf /\n")
  let bytes = make_tree_payload_with_name(
    "100644", ".git/hooks/post-checkout", blob_id,
  )
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].name, ".git/hooks/post-checkout")
}

///|
/// `entry.name == ".."` is accepted. The join becomes `<root>/..`
/// which is the *parent* of the worktree.
test "security: parse_tree accepts entry name '..'" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", "..", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].name, "..")
}

///|
/// `entry.name` containing only `.` is also accepted (Git rejects
/// this since it would alias the directory itself).
test "security: parse_tree accepts entry name '.'" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", ".", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].name, ".")
}

///|
/// Empty `entry.name` is also accepted. The join yields the worktree
/// root itself; a subsequent `fs.write_file(root, ...)` would clobber
/// the worktree directory.
test "security: parse_tree accepts empty entry name" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", "", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].name, "")
}

///|
/// `.gitmodules` containing a submodule path with `..` segments —
/// the classic CVE-2018-11235 / -17456 / -1387 family. Bit doesn't
/// currently parse / validate `.gitmodules` at the materialization
/// step; the file is just written like any other blob. We pin this
/// fact so that, once `.gitmodules` parsing is added, this test will
/// surface that the validator must reject path-escaping module
/// definitions before recursive clone / submodule init.
///|
/// `pktline_decode` reads a 4-byte hex length, then `payload_len = len - 4`.
/// For `len ∈ {2, 3}`, `payload_len` is negative; the bounds check
/// `offset + payload_len > data.length()` does not catch this (the
/// parser is asking "is offset *minus* something past EOF" which is
/// always false), and `offset += payload_len` moves the cursor
/// backwards. The parser eventually raises on a re-read mismatch, but
/// the wrong reason — the bug is in trusting `len ≥ 4`. A future patch
/// should reject `len == 2 || len == 3` up front.
test "security: pktline_decode does not reject sub-header lengths up front" {
  // Hex "0002" → length 2 → payload_len = -2.
  let bytes = b"0002"
  // We intentionally only check that the function doesn't crash; the
  // behavior on this input is "raise eventually", which is acceptable
  // *symptom* but the underlying input validation is missing.
  let parsed = @protocol.pktline_decode(bytes) catch { _ => [] }
  let _ = parsed
}

test "security: .gitmodules with traversal path is not pre-validated" {
  let content =
    #|[submodule "evil"]
    #|	path = ../../escape
    #|	url = https://example.com/x
    #|
  let blob_id = @bit.hash_blob(@utf8.encode(content))
  let bytes = make_tree_payload_with_name("100644", ".gitmodules", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries[0].name, ".gitmodules")
  // Bit currently has no path validator at this layer; the blob is
  // accepted as-is. A future submodule-init path needs to refuse
  // module paths that, when resolved against the worktree root,
  // escape it.
}
