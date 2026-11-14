///|
fn session_json_get_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn session_json_get_string(obj : Json, key : String) -> String? {
  match session_json_get_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
test "session manager stores and returns recent history" {
  let now = Ref(100)
  let manager = SessionManager::new(clock=fn() { now.val })
  let session = manager.get_or_create("cli:1")
  session.add_message("user", "hello")
  now.val = 110
  session.add_message("assistant", "world")
  manager.save(session)
  let history = session.get_history(max_messages=1)
  assert_eq(history.length(), 1)
  @debug.debug_inspect(
    session_json_get_string(history[0], "role"),
    content="Some(\"assistant\")",
  )
  @debug.debug_inspect(
    session_json_get_string(history[0], "content"),
    content="Some(\"world\")",
  )
}

///|
test "session manager list sorts by updated time desc" {
  let now = Ref(10)
  let manager = SessionManager::new(clock=fn() { now.val })
  let s1 = manager.get_or_create("cli:1")
  s1.add_message("user", "a")
  manager.save(s1)
  now.val = 20
  let s2 = manager.get_or_create("cli:2")
  s2.add_message("user", "b")
  manager.save(s2)
  let listed = manager.list_sessions()
  assert_eq(listed.length(), 2)
  assert_eq(listed[0].key, "cli:2")
  assert_eq(listed[1].key, "cli:1")
}

///|
test "session manager delete removes session" {
  let manager = SessionManager::new()
  let s = manager.get_or_create("cli:gone")
  s.add_message("user", "x")
  manager.save(s)
  assert_true(manager.delete("cli:gone"))
  assert_true(!manager.delete("cli:gone"))
  let listed = manager.list_sessions()
  @debug.debug_inspect(listed.length(), content="0")
}
