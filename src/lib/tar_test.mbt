///| Tests for tar generation helpers

///|
test "tar_format_octal: zero value" {
  let result = tar_format_octal(0L, 7)
  assert_eq(result, "0000000")
}

///|
test "tar_format_octal: zero with width 11" {
  let result = tar_format_octal(0L, 11)
  assert_eq(result, "00000000000")
}

///|
test "tar_format_octal: file mode 0o100644" {
  let result = tar_format_octal(0o100644L, 7)
  assert_eq(result, "0100644")
}

///|
test "tar_format_octal: dir mode 0o40755" {
  let result = tar_format_octal(0o40755L, 7)
  assert_eq(result, "0040755")
}

///|
test "tar_format_octal: file size 1024" {
  let result = tar_format_octal(1024L, 11)
  assert_eq(result, "00000002000")
}

///|
test "tar_format_octal: large timestamp" {
  // 1700000000 decimal = 14524770400 octal
  let result = tar_format_octal(1700000000L, 11)
  assert_eq(result, "14524770400")
}

///|
test "tar_split_path: short path no split needed" {
  let (name, prefix) = tar_split_path("src/main.mbt")
  // Should still split at the last valid '/'
  assert_eq(name, "main.mbt")
  assert_eq(prefix, "src")
}

///|
test "tar_split_path: long path splits at slash boundary" {
  // Build a path longer than 100 chars
  let long_dir = "a".repeat(80)
  let path = long_dir + "/file.txt"
  let (name, prefix) = tar_split_path(path)
  assert_eq(name, "file.txt")
  assert_eq(prefix, long_dir)
}

///|
test "tar_write_string: basic write" {
  let buf = FixedArray::make(16, b'\x00')
  tar_write_string(buf, 0, "hello", 16)
  assert_eq(buf[0], b'h')
  assert_eq(buf[1], b'e')
  assert_eq(buf[2], b'l')
  assert_eq(buf[3], b'l')
  assert_eq(buf[4], b'o')
  assert_eq(buf[5], b'\x00') // untouched
}

///|
test "tar_write_string: truncates at max_len" {
  let buf = FixedArray::make(8, b'\x00')
  tar_write_string(buf, 0, "abcdefghijk", 3)
  assert_eq(buf[0], b'a')
  assert_eq(buf[1], b'b')
  assert_eq(buf[2], b'c')
  assert_eq(buf[3], b'\x00') // not written
}

///|
test "tar_make_header: produces 512-byte header" {
  let hdr = tar_make_header("test.txt", 0o100644, 42, 1700000000L, b'0', "")
  assert_eq(hdr.length(), 512)
}

///|
test "tar_make_header: name field" {
  let hdr = tar_make_header("hello.txt", 0o100644, 0, 0L, b'0', "")
  // name starts at offset 0
  assert_eq(hdr[0], b'h')
  assert_eq(hdr[1], b'e')
  assert_eq(hdr[2], b'l')
  assert_eq(hdr[3], b'l')
  assert_eq(hdr[4], b'o')
  assert_eq(hdr[5], b'.')
  assert_eq(hdr[6], b't')
  assert_eq(hdr[7], b'x')
  assert_eq(hdr[8], b't')
}

///|
test "tar_make_header: magic field is ustar" {
  let hdr = tar_make_header("f.txt", 0o100644, 0, 0L, b'0', "")
  // magic at offset 257, 5 bytes "ustar"
  assert_eq(hdr[257], b'u')
  assert_eq(hdr[258], b's')
  assert_eq(hdr[259], b't')
  assert_eq(hdr[260], b'a')
  assert_eq(hdr[261], b'r')
  assert_eq(hdr[262], b'\x00')
  // version at offset 263: "00"
  assert_eq(hdr[263], b'0')
  assert_eq(hdr[264], b'0')
}

///|
test "tar_make_header: typeflag for directory" {
  let hdr = tar_make_header("dir/", 0o40755, 0, 0L, b'5', "")
  // typeflag at offset 156
  assert_eq(hdr[156], b'5')
}

///|
test "tar_make_header: checksum is valid" {
  let hdr = tar_make_header("test.txt", 0o100644, 100, 1700000000L, b'0', "")
  // Recompute checksum: sum all bytes, treating checksum field (148..156) as spaces
  let mut expected_sum = 0
  for i in 0..<512 {
    if i >= 148 && i < 156 {
      expected_sum += b' '.to_int()
    } else {
      expected_sum += hdr[i].to_int()
    }
  }
  // Read the stored checksum from offset 148 (6-digit octal + NUL + space)
  let mut stored_sum = 0
  for i in 0..<6 {
    let digit = hdr[148 + i].to_int() - '0'.to_int()
    stored_sum = stored_sum * 8 + digit
  }
  assert_eq(hdr[148 + 6], b'\x00')
  assert_eq(hdr[148 + 7], b' ')
  assert_eq(stored_sum, expected_sum)
}

///|
test "tar_make_header: symlink with linkname" {
  let hdr = tar_make_header("link.txt", 0o120000, 0, 0L, b'2', "target.txt")
  assert_eq(hdr[156], b'2')
  // linkname at offset 157
  assert_eq(hdr[157], b't')
  assert_eq(hdr[158], b'a')
  assert_eq(hdr[159], b'r')
  assert_eq(hdr[160], b'g')
}

///|
test "tar_parse_committer_timestamp: valid commit" {
  let commit_text = "tree 0000000000000000000000000000000000000000\nauthor Test <test@test.com> 1700000000 +0000\ncommitter Test <test@test.com> 1700000001 +0000\n\nmessage\n"
  let data = @utf8.encode(commit_text)
  let ts = tar_parse_committer_timestamp(data)
  assert_eq(ts, 1700000001L)
}

///|
test "tar_parse_committer_timestamp: no committer line" {
  let text = "tree 0000000000000000000000000000000000000000\n\nmessage\n"
  let data = @utf8.encode(text)
  let ts = tar_parse_committer_timestamp(data)
  assert_eq(ts, 0L)
}

///|
test "tar_emit_parent_dirs: creates directory entries" {
  let out : Array[Byte] = []
  let emitted : Map[String, Bool] = {}
  tar_emit_parent_dirs(out, "a/b/c/file.txt", 0L, emitted)
  // Should emit 3 directory entries: a/, a/b/, a/b/c/
  // Each directory entry is 512 bytes
  assert_eq(out.length(), 512 * 3)
  assert_true(emitted.contains("a/"))
  assert_true(emitted.contains("a/b/"))
  assert_true(emitted.contains("a/b/c/"))
}

///|
test "tar_emit_parent_dirs: skips already emitted" {
  let out : Array[Byte] = []
  let emitted : Map[String, Bool] = {}
  emitted["a/"] = true
  emitted["a/b/"] = true
  tar_emit_parent_dirs(out, "a/b/c/file.txt", 0L, emitted)
  // Only a/b/c/ should be emitted (512 bytes)
  assert_eq(out.length(), 512)
  assert_true(emitted.contains("a/b/c/"))
}

///|
test "tar: complete archive with header + data + end blocks" {
  let out : Array[Byte] = []
  let content = "Hello, world!\n"
  let content_bytes = @utf8.encode(content)
  let size = content_bytes.length()
  // Write header
  let hdr = tar_make_header("hello.txt", 0o100644, size, 0L, b'0', "")
  for b in hdr {
    out.push(b)
  }
  // Write content
  for i in 0..<size {
    out.push(content_bytes[i])
  }
  // Pad to 512-byte boundary
  let remainder = size % 512
  if remainder > 0 {
    let pad = 512 - remainder
    for _k in 0..<pad {
      out.push(b'\x00')
    }
  }
  // End-of-archive: two 512-byte zero blocks
  for _k in 0..<1024 {
    out.push(b'\x00')
  }
  // Total: 512 (header) + 512 (data padded) + 1024 (end) = 2048
  assert_eq(out.length(), 2048)
  // Verify the data starts right after the header
  assert_eq(out[512], b'H')
  assert_eq(out[513], b'e')
  // Verify end blocks are zeros
  assert_eq(out[2047], b'\x00')
}
