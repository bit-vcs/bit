///|
async test "fallback: check_and_exit_unsupported_attrs passes for text/eol attributes" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-fallback-gitattr-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root + "/.git")
  let cleanup = fn() {
    fs.remove_file(root + "/.gitattributes") catch {
      _ => ()
    }
    fs.remove_file(root + "/.git/config") catch {
      _ => ()
    }
    fs.remove_dir(root + "/.git") catch {
      _ => ()
    }
    fs.remove_dir(root) catch {
      _ => ()
    }
  }

  // text/eol attributes are handled natively - should not exit
  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt -text\n"))
  check_and_exit_unsupported_attrs(root) // should not exit

  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt text\n"))
  check_and_exit_unsupported_attrs(root) // should not exit

  fs.write_file(root + "/.gitattributes", string_to_bytes("*.txt eol=crlf\n"))
  check_and_exit_unsupported_attrs(root) // should not exit

  // Generic filter= is now handled natively - should not exit
  fs.write_file(
    root + "/.gitattributes",
    string_to_bytes("*.txt filter=foo diff=bar\n"),
  )
  check_and_exit_unsupported_attrs(root) // should not exit

  fs.write_file(
    root + "/.gitattributes",
    string_to_bytes("# comment only\n   \n"),
  )
  check_and_exit_unsupported_attrs(root) // should not exit
  cleanup()
}
