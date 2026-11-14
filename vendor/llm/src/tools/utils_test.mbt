///|
test "resolve_path blocks traversal and enforces allowed dir" {
  match resolve_path("../etc/passwd", Some("/ws")) {
    Ok(_) => assert_true(false)
    Err(err) => assert_true(err.contains("Path traversal"))
  }
  match resolve_path("/ws/a.txt", Some("/ws")) {
    Ok(path) => assert_eq(path, "/ws/a.txt")
    Err(_) => assert_true(false)
  }
  match resolve_path("/etc/passwd", Some("/ws")) {
    Ok(_) => assert_true(false)
    Err(err) => assert_true(err.contains("outside allowed directory"))
  }
}

///|
test "guard_command blocks dangerous fragments" {
  match guard_command("rm -rf /", false) {
    Some(err) => assert_true(err.contains("blocked by safety guard"))
    None => assert_true(false)
  }
  match guard_command("ls -la", false) {
    Some(_) => assert_true(false)
    None => assert_true(true)
  }
}

///|
test "validate_url allows http https only" {
  match validate_url("https://example.com") {
    Ok(_) => assert_true(true)
    Err(_) => assert_true(false)
  }
  match validate_url("file:///tmp/a") {
    Ok(_) => assert_true(false)
    Err(err) => assert_true(err.contains("Only http/https"))
  }
}

///|
test "json field helpers parse required/optional values" {
  let obj : Json = { "name": ToJson::to_json("alice"), "count": ToJson::to_json((3)) }
  @debug.debug_inspect(required_string(obj, "name"), content="Some(\"alice\")")
  @debug.debug_inspect(optional_string(obj, "name"), content="Some(\"alice\")")
  @debug.debug_inspect(optional_int(obj, "count"), content="Some(3)")
  @debug.debug_inspect(required_string(obj, "missing"), content="None")
}
