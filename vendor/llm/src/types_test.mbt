///|
test "Role::to_string" {
  @debug.debug_inspect(
    Role::User.to_string(),
    content=(
      #|"user"
    ),
  )
  @debug.debug_inspect(
    Role::Assistant.to_string(),
    content=(
      #|"assistant"
    ),
  )
  @debug.debug_inspect(
    Role::System.to_string(),
    content=(
      #|"system"
    ),
  )
  @debug.debug_inspect(
    Role::Tool.to_string(),
    content=(
      #|"tool"
    ),
  )
}

///|
test "Role::from_string" {
  @debug.debug_inspect(
    Role::from_string("user"),
    content=(
      #|User
    ),
  )
  @debug.debug_inspect(
    Role::from_string("assistant"),
    content=(
      #|Assistant
    ),
  )
  @debug.debug_inspect(
    Role::from_string("system"),
    content=(
      #|System
    ),
  )
  @debug.debug_inspect(
    Role::from_string("tool"),
    content=(
      #|Tool
    ),
  )
  @debug.debug_inspect(
    Role::from_string("unknown"),
    content=(
      #|User
    ),
  )
}

///|
test "Message::text" {
  let msg = Message::text(User, "hello")
  @debug.debug_inspect(
    msg.role,
    content=(
      #|User
    ),
  )
  @debug.debug_inspect(
    msg.get_text(),
    content=(
      #|"hello"
    ),
  )
}

///|
test "Message::user" {
  let msg = Message::user("hi")
  @debug.debug_inspect(
    msg.role,
    content=(
      #|User
    ),
  )
  @debug.debug_inspect(
    msg.get_text(),
    content=(
      #|"hi"
    ),
  )
}

///|
test "Message::assistant" {
  let msg = Message::assistant("reply")
  @debug.debug_inspect(
    msg.role,
    content=(
      #|Assistant
    ),
  )
  @debug.debug_inspect(
    msg.get_text(),
    content=(
      #|"reply"
    ),
  )
}

///|
test "Message::get_text with multiple blocks" {
  let msg : Message = {
    role: Assistant,
    content: [Text("hello "), Text("world")],
  }
  @debug.debug_inspect(
    msg.get_text(),
    content=(
      #|"hello world"
    ),
  )
}

///|
test "Message::get_text ignores non-text blocks" {
  let msg : Message = {
    role: Assistant,
    content: [Text("text"), ToolUse(id="1", name="tool", input=Json::null())],
  }
  @debug.debug_inspect(
    msg.get_text(),
    content=(
      #|"text"
    ),
  )
}

///|
test "FinishReason::from_string" {
  @debug.debug_inspect(FinishReason::from_string("stop"), content="Stop")
  @debug.debug_inspect(FinishReason::from_string("end_turn"), content="Stop")
  @debug.debug_inspect(FinishReason::from_string("tool_use"), content="ToolUse")
  @debug.debug_inspect(
    FinishReason::from_string("tool_calls"),
    content="ToolUse",
  )
  @debug.debug_inspect(FinishReason::from_string("length"), content="Length")
  @debug.debug_inspect(
    FinishReason::from_string("max_tokens"),
    content="Length",
  )
  @debug.debug_inspect(
    FinishReason::from_string("content_filter"),
    content="ContentFilter",
  )
  @debug.debug_inspect(FinishReason::from_string("error"), content="Error")
  @debug.debug_inspect(
    FinishReason::from_string("xyz"),
    content=(
      #|Unknown("xyz")
    ),
  )
}
