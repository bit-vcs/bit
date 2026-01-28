///| Utility to generate a packfile for testing with git verify-pack

///| This can be compiled and run to produce a packfile on stdout

// This file is for manual testing - not included in normal builds
// To test:
//   1. Build this as a standalone program
//   2. Run: ./gen_packfile > test.pack
//   3. Verify: git verify-pack -v test.pack

///|
pub fn generate_test_packfile() -> Bytes {
  // Create a simple blob packfile with "hello\n"
  let content = Bytes::from_array([b'h', b'e', b'l', b'l', b'o', b'\n'])
  create_blob_packfile(content)
}

///|
pub fn generate_commit_packfile() -> (ObjectId, Bytes) {
  // Create a full commit packfile with blob, tree, and commit
  let blob_content = Bytes::from_array([b'h', b'e', b'l', b'l', b'o', b'\n'])
  let commit = Commit::new(
    ObjectId::zero(), // placeholder
    [],
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Test Author <test@example.com>",
    1700000000L,
    "+0000",
    "Initial commit\n",
  )
  create_commit_packfile(blob_content, "hello.txt", commit)
}

///|
/// Print packfile as hex dump for debugging
pub fn hex_dump(data : Bytes) -> String {
  let result = StringBuilder::new()
  for i = 0; i < data.length(); i = i + 1 {
    if i > 0 && i % 16 == 0 {
      result.write_char('\n')
    } else if i > 0 && i % 8 == 0 {
      result.write_char(' ')
    }
    let b = data[i].to_int()
    let hi = b >> 4
    let lo = b & 0x0f
    result.write_char(hex_digit(hi))
    result.write_char(hex_digit(lo))
    result.write_char(' ')
  }
  result.to_string()
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    (n + 48).unsafe_to_char() // '0' = 48
  } else {
    (n - 10 + 97).unsafe_to_char() // 'a' = 97
  }
}
