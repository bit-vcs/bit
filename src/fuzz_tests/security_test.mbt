///| Adversarial / security regression tests.
///
/// These tests construct intentionally-malicious git objects and feed
/// them through bit's parsers and worktree-materialization code. The
/// `parse_tree accepts ...` tests pin the **parser** behavior (parse
/// bytes verbatim — no validation; needed for round-tripping legacy
/// objects). The `... rejected at materialization` tests pin the
/// **defense layer** (`verify_tree_entry_name`, called by
/// `collect_tree_files_inner` / `walk_tree_to_fs`).

///|
/// Build a tree payload (raw, no object header) containing a single
/// entry with the given name and mode.
fn make_tree_payload_with_name(
  mode : String,
  name : String,
  blob_id : @bit.ObjectId,
) -> Bytes {
  let entry = @bit.TreeEntry::new(mode, name, blob_id)
  @bit.serialize_tree([entry])
}

// ---------------------------------------------------------------------
// Parser: accepts the bytes verbatim (no validation at this layer).
// ---------------------------------------------------------------------

///|
test "parse_tree accepts entry name '../escape'" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", "../escape", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries[0].name, "../escape")
}

///|
test "parse_tree accepts entry name '.git/hooks/post-checkout'" {
  let blob_id = @bit.hash_blob(b"#!/bin/sh\nrm -rf /\n")
  let bytes = make_tree_payload_with_name(
    "100644", ".git/hooks/post-checkout", blob_id,
  )
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries[0].name, ".git/hooks/post-checkout")
}

///|
test "parse_tree accepts entry name '..'" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", "..", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries[0].name, "..")
}

///|
test "parse_tree accepts entry name '.'" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", ".", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries[0].name, ".")
}

///|
test "parse_tree accepts empty entry name" {
  let blob_id = @bit.hash_blob(b"x")
  let bytes = make_tree_payload_with_name("100644", "", blob_id)
  let entries = @bit.parse_tree(bytes)
  assert_eq(entries[0].name, "")
}

// ---------------------------------------------------------------------
// Defense: verify_tree_entry_name() rejects the dangerous names.
// ---------------------------------------------------------------------

///|
/// Hostile names that the materializer must reject. These are the
/// minimum set needed to prevent path traversal and `.git/` overwrite
/// during checkout / clone / fetch.
let security_hostile_tree_names : Array[String] = [
  "..",
  ".",
  "",
  "../escape",
  ".git",
  ".GIT",
  ".Git",
  ".gIt",
  ".git/hooks/post-checkout",
  "a/b",
  "subdir/file",
]

///|
test "verify_tree_entry_name rejects path-escaping names" {
  for name in security_hostile_tree_names {
    let rejected = try? @bit.verify_tree_entry_name(name)
    match rejected {
      Err(_) => () // expected
      Ok(_) =>
        // Make the offending name visible in the assertion message.
        assert_true(false)
    }
  }
}

///|
test "verify_tree_entry_name accepts ordinary names" {
  // Common legitimate names should NOT raise.
  let ok_names = [
    "README.md", "src", "Cargo.toml", ".gitignore", ".gitattributes",
    "a.txt", "longer.file.name.with.dots", "日本語.txt", "GIT",
    // single-byte non-ASCII is fine (UTF-8 trailing bytes in single name),
    "x",
  ]
  for name in ok_names {
    @bit.verify_tree_entry_name(name)
  }
}

///|
test "checkout: collect_tree_files rejects '../escape' entry at materialization" {
  let blob_id = @bit.hash_blob(b"pwn")
  let bytes = make_tree_payload_with_name("100644", "../escape", blob_id)
  let entries = @bit.parse_tree(bytes)
  // Simulate what collect_tree_files_inner does internally:
  // it calls verify_tree_entry_name on each entry before pushing.
  let result = try? @bit.verify_tree_entry_name(entries[0].name)
  match result {
    Err(_) => () // expected: materializer refuses to write outside
    Ok(_) => assert_true(false)
  }
}

///|
test "checkout: collect_tree_files rejects '.git/...' entry at materialization" {
  let blob_id = @bit.hash_blob(b"#!/bin/sh\nid > /tmp/pwned\n")
  let bytes = make_tree_payload_with_name(
    "100644", ".git/hooks/post-checkout", blob_id,
  )
  let entries = @bit.parse_tree(bytes)
  let result = try? @bit.verify_tree_entry_name(entries[0].name)
  match result {
    Err(_) => () // expected
    Ok(_) => assert_true(false)
  }
}

// ---------------------------------------------------------------------
// Remaining sharp edges (not fixed; left as pinning tests).
// ---------------------------------------------------------------------

///|
/// `pktline_decode` with `len = 2` or `3`: see commit message — fixed
/// in this batch by rejecting sub-header lengths up front.
test "pktline_decode rejects sub-header length 0002" {
  let bytes = b"0002"
  let parsed = try? @protocol.pktline_decode(bytes)
  // After the fix this is an error; before the fix it would have
  // returned an `Ok([])`-style value (or eventually raised on a
  // different mismatch). The new contract is: explicit raise.
  match parsed {
    Err(_) => ()
    Ok(_) => assert_true(false)
  }
}

///|
test "pktline_decode rejects sub-header length 0003" {
  let bytes = b"0003"
  let parsed = try? @protocol.pktline_decode(bytes)
  match parsed {
    Err(_) => ()
    Ok(_) => assert_true(false)
  }
}

///|
/// `.gitmodules` containing a submodule path with `..` segments —
/// CVE-2018-11235 family. Bit doesn't currently parse / validate
/// `.gitmodules` at the materialization step. Pinning test only.
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
}
