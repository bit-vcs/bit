///|
fn tree_entry_name_rejected(name : String, mode? : String = "100644") -> Bool {
  try {
    verify_tree_entry_name(name, mode~)
    false
  } catch {
    _ => true
  }
}

///|
test "verify_tree_entry_name: repository marker spellings are rejected" {
  for name in [
    ".git", ".GIT", ".Git", ".bit", ".BIT",
    // NTFS: trailing dots/spaces, 8.3 short names, alternate data streams
    ".git.", ".git ", ".git . .", "git~1", "GIT~1", "git~1.", ".git::$INDEX_ALLOCATION",
    ".git:stream", "bit~1", ".bit.",
    // NTFS: backslash is a separator on Windows
    "a\\.git", ".git\\x", "x\\git~1\\y",
    // HFS+: ignorable code points
    ".g\u{200c}it", ".\u{200d}git", ".gi\u{feff}t", ".git\u{206a}", "\u{202e}.GIT",
    ".b\u{200c}it",
  ] {
    if !tree_entry_name_rejected(name) {
      fail("expected '\{name}' to be rejected")
    }
  }
}

///|
test "verify_tree_entry_name: ordinary dot names are accepted" {
  for name in [
    ".github", ".gitignore", ".gitmodules", ".gitattributes", ".gitkeep",
    "git", "git~2", ".git~1", "gitx", ".gi", ".bitrc", "bit", "a.git", "x\\y",
    ".g\u{200c}ithub", "git~10",
  ] {
    if tree_entry_name_rejected(name) {
      fail("expected '\{name}' to be accepted")
    }
  }
}

///|
test "verify_tree_entry_name: symlinked git dotfiles are rejected" {
  for name in [
    ".gitmodules", ".GITMODULES", ".gitattributes", ".gitignore", ".mailmap",
    "gitmod~1", ".gitmodules.", ".g\u{200c}itmodules",
  ] {
    if !tree_entry_name_rejected(name, mode="120000") {
      fail("expected symlink '\{name}' to be rejected")
    }
  }
  // As regular files they are fine.
  for name in [".gitmodules", ".gitattributes", ".gitignore", ".mailmap"] {
    if tree_entry_name_rejected(name) {
      fail("expected regular file '\{name}' to be accepted")
    }
  }
  // Other symlinks are fine.
  if tree_entry_name_rejected("link", mode="120000") {
    fail("expected an ordinary symlink to be accepted")
  }
}
