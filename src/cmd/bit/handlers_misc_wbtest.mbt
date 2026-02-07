///|
test "config: set_config escapes double quotes in value" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-config-escape-" + get_current_timestamp().to_string()
  fs.mkdir_p(root)
  let config_path = root + "/config"
  set_config(
    fs,
    config_path,
    "remote.origin.uploadpack",
    "\"$TRASH_DIRECTORY/fake-upload-pack\"",
    false,
  )
  let content = decode_bytes(fs.read_file(config_path))
  assert_true(
    content.contains(
      "uploadpack = \\\"$TRASH_DIRECTORY/fake-upload-pack\\\"",
    ),
  )
  fs.remove_file(config_path) catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}

///|
test "config: set_config escapes quotes when appending to existing section" {
  let fs = OsFs::new()
  let root = "/tmp/bit-test-config-escape-existing-" +
    get_current_timestamp().to_string()
  fs.mkdir_p(root)
  let config_path = root + "/config"
  let base_config =
    #|
    #|[remote "origin"]
    #|  url = https://example.com/repo.git
    #|[branch "main"]
    #|  remote = origin
  fs.write_string(
    config_path,
    base_config,
  )
  set_config(
    fs,
    config_path,
    "remote.origin.uploadpack",
    "\"$TRASH_DIRECTORY/fake-upload-pack\"",
    false,
  )
  let content = decode_bytes(fs.read_file(config_path))
  assert_true(
    content.contains(
      "uploadpack = \\\"$TRASH_DIRECTORY/fake-upload-pack\\\"",
    ),
  )
  fs.remove_file(config_path) catch {
    _ => ()
  }
  fs.remove_dir(root) catch {
    _ => ()
  }
}
