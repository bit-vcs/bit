///| Tests for relay watch/status helper functions

///|
test "relay_resolve_room_arg: namespace" {
  let (base, room) = relay_resolve_room_arg("mizchi/vibe-lang")
  assert_true(base.contains("bit-relay"))
  assert_eq(room, "mizchi/vibe-lang")
}

///|
test "relay_resolve_room_arg: simple name" {
  let (base, room) = relay_resolve_room_arg("my-project")
  assert_true(base.contains("bit-relay"))
  assert_eq(room, "my-project")
}

///|
test "relay_resolve_room_arg: full URL with room" {
  let (base, room) = relay_resolve_room_arg(
    "relay+https://custom.relay.dev?room=test-room",
  )
  assert_eq(base, "https://custom.relay.dev")
  assert_eq(room, "test-room")
}

///|
test "relay_resolve_room_arg: full URL without room" {
  let (base, room) = relay_resolve_room_arg("relay+https://custom.relay.dev")
  assert_eq(base, "https://custom.relay.dev")
  assert_eq(room, "default")
}

///|
test "relay_safe_sender: from env" {
  let prev = @sys.get_env_var("BIT_RELAY_SENDER")
  @sys.set_env_var("BIT_RELAY_SENDER", "test-bot")
  let sender = relay_safe_sender()
  assert_eq(sender, "test-bot")
  match prev {
    Some(v) => @sys.set_env_var("BIT_RELAY_SENDER", v)
    None => @sys.unset_env_var("BIT_RELAY_SENDER")
  }
}

///|
test "relay_watch_print_envelope: formats hub record" {
  // Just verify no crash — output goes to stdout
  let envelope : Json = {
    "sender": "alice",
    "topic": "hub.issue",
    "id": "12345678abcdef",
    "payload": {
      "kind": "hub.record",
      "record": "version: 1\ntitle: Test Issue\nstate: open",
    },
  }
  relay_watch_print_envelope(envelope)
}

///|
test "relay_watch_print_envelope: formats ci status" {
  let envelope : Json = {
    "sender": "ci",
    "topic": "ci.status",
    "id": "ci-main-pass",
    "payload": { "kind": "ci.status", "ref": "main", "status": "pass" },
  }
  relay_watch_print_envelope(envelope)
}

///|
test "relay_watch_summarize_hub_record: extracts title" {
  let payload : Map[String, Json] = {}
  payload["record"] = Json::string(
    "version: 1\ntitle: My Issue Title\nstate: open",
  )
  let summary = relay_watch_summarize_hub_record(payload)
  assert_eq(summary, "My Issue Title")
}

///|
test "relay_watch_summarize_hub_record: no title" {
  let payload : Map[String, Json] = {}
  payload["record"] = Json::string("version: 1\nstate: open")
  let summary = relay_watch_summarize_hub_record(payload)
  assert_eq(summary, "hub.record")
}
