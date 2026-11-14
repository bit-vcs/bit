///|
fn runtime_core_json_get_field(obj : Json, key : String) -> Json? {
  match obj {
    Object(map) => map.get(key)
    _ => None
  }
}

///|
fn runtime_core_json_get_string(obj : Json, key : String) -> String? {
  match runtime_core_json_get_field(obj, key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
test "run_runtime_turn stores user/assistant history for user inbound" {
  let sessions = SessionManager::new()
  let seen_history_len = Ref(-1)
  let req = RuntimeTurnRequest::new(
    UserInbound,
    "cli:42",
    "cli",
    "42",
    "u1",
    "hello",
  )
  let result = run_runtime_turn(sessions, req, fn(
    history,
    current,
    _channel,
    _chat_id,
  ) {
    seen_history_len.val = history.length()
    "reply:" + current
  })
  assert_eq(seen_history_len.val, 0)
  assert_eq(result.channel, "cli")
  assert_eq(result.chat_id, "42")
  assert_eq(result.content, "reply:hello")
  let session = sessions.get_or_create("cli:42")
  let hist = session.get_history()
  assert_eq(hist.length(), 2)
  @debug.debug_inspect(
    runtime_core_json_get_string(hist[0], "content"),
    content="Some(\"hello\")",
  )
  @debug.debug_inspect(
    runtime_core_json_get_string(hist[1], "content"),
    content="Some(\"reply:hello\")",
  )
}

///|
test "run_runtime_turn prefixes system sender and drops outbound metadata" {
  let sessions = SessionManager::new()
  let req = RuntimeTurnRequest::new(
    SystemInbound,
    "telegram:abc",
    "telegram",
    "abc",
    "subagent",
    "background done",
    metadata={ "origin": ToJson::to_json("x") },
  )
  let result = run_runtime_turn(sessions, req, fn(
    _history,
    _current,
    _channel,
    _chat_id,
  ) {
    "summary"
  })
  assert_eq(result.content, "summary")
  assert_eq(result.metadata.length(), 0)
  let session = sessions.get_or_create("telegram:abc")
  let hist = session.get_history()
  @debug.debug_inspect(
    runtime_core_json_get_string(hist[0], "content"),
    content="Some(\"[System: subagent] background done\")",
  )
}
