///|
/// Role represents the sender of a message in a conversation.
pub(all) enum Role {
  User
  Assistant
  System
  Tool
} derive(Eq, @debug.Debug)

///|
pub impl Show for Role with fn output(self, logger) {
  match self {
    User => logger.write_string("user")
    Assistant => logger.write_string("assistant")
    System => logger.write_string("system")
    Tool => logger.write_string("tool")
  }
}

///|
pub fn Role::to_string(self : Role) -> String {
  match self {
    User => "user"
    Assistant => "assistant"
    System => "system"
    Tool => "tool"
  }
}

///|
pub fn Role::from_string(s : String) -> Role {
  match s {
    "user" => User
    "assistant" => Assistant
    "system" => System
    "tool" => Tool
    _ => User
  }
}

///|
/// ContentBlock represents typed content within a message.
pub(all) enum ContentBlock {
  Text(String)
  ToolUse(id~ : String, name~ : String, input~ : Json)
  ToolResult(tool_use_id~ : String, content~ : String, is_error~ : Bool)
}

///|
/// Message represents a single message in a conversation.
pub(all) struct Message {
  role : Role
  content : Array[ContentBlock]
}

///|
/// Create a simple text message.
pub fn Message::text(role : Role, text : String) -> Message {
  { role, content: [Text(text)] }
}

///|
/// Create a user text message.
pub fn Message::user(text : String) -> Message {
  Message::text(User, text)
}

///|
/// Create an assistant text message.
pub fn Message::assistant(text : String) -> Message {
  Message::text(Assistant, text)
}

///|
/// Create a system text message.
pub fn Message::system(text : String) -> Message {
  Message::text(System, text)
}

///|
/// Get the text content of a message (concatenated from all Text blocks).
pub fn Message::get_text(self : Message) -> String {
  let buf = StringBuilder::new()
  for block in self.content {
    match block {
      Text(s) => buf.write_string(s)
      _ => ()
    }
  }
  buf.to_string()
}

///|
/// ToolCall represents a tool invocation from the model.
pub(all) struct ToolCall {
  id : String
  name : String
  input : Json
}

///|
/// Usage tracks token consumption.
pub(all) struct Usage {
  input_tokens : Int
  output_tokens : Int
} derive(@debug.Debug)

///|
/// FinishReason indicates why the model stopped generating.
pub(all) enum FinishReason {
  Stop
  ToolUse
  Length
  ContentFilter
  Error
  Unknown(String)
} derive(@debug.Debug)

///|
pub impl Show for FinishReason with fn output(self, logger) {
  match self {
    Stop => logger.write_string("Stop")
    ToolUse => logger.write_string("ToolUse")
    Length => logger.write_string("Length")
    ContentFilter => logger.write_string("ContentFilter")
    Error => logger.write_string("Error")
    Unknown(s) => {
      logger.write_string("Unknown(")
      logger.write_string(s)
      logger.write_string(")")
    }
  }
}

///|
pub fn FinishReason::from_string(s : String) -> FinishReason {
  match s {
    "stop" | "end_turn" => Stop
    "tool_use" | "tool_calls" => ToolUse
    "length" | "max_tokens" => Length
    "content_filter" => ContentFilter
    "error" => Error
    other => Unknown(other)
  }
}

///|
/// StreamEvent represents events during streaming generation.
pub(all) enum StreamEvent {
  TextDelta(String)
  ToolCallStart(id~ : String, name~ : String)
  ToolCallDelta(id~ : String, input_delta~ : String)
  ToolCallEnd(id~ : String, name~ : String, input~ : Json)
  MessageStart
  MessageEnd(finish_reason~ : FinishReason, usage~ : Usage?)
  Error(String)
}

///|
pub impl Show for Usage with fn output(self, logger) {
  logger.write_string("Usage(in=")
  logger.write_string(self.input_tokens.to_string())
  logger.write_string(",out=")
  logger.write_string(self.output_tokens.to_string())
  logger.write_string(")")
}

///|
pub impl Show for StreamEvent with fn output(self, logger) {
  match self {
    TextDelta(s) => {
      logger.write_string("TextDelta(")
      logger.write_string(s)
      logger.write_string(")")
    }
    ToolCallStart(id~, name~) => {
      logger.write_string("ToolCallStart(id=")
      logger.write_string(id)
      logger.write_string(",name=")
      logger.write_string(name)
      logger.write_string(")")
    }
    ToolCallDelta(id~, input_delta~) => {
      logger.write_string("ToolCallDelta(id=")
      logger.write_string(id)
      logger.write_string(",delta=")
      logger.write_string(input_delta)
      logger.write_string(")")
    }
    ToolCallEnd(id~, name~, input~) => {
      logger.write_string("ToolCallEnd(id=")
      logger.write_string(id)
      logger.write_string(",name=")
      logger.write_string(name)
      logger.write_string(",input=")
      logger.write_string(input.stringify())
      logger.write_string(")")
    }
    MessageStart => logger.write_string("MessageStart")
    MessageEnd(finish_reason~, usage~) => {
      logger.write_string("MessageEnd(reason=")
      logger.write_string(@debug.to_string(finish_reason))
      logger.write_string(",usage=")
      logger.write_string(@debug.to_string(usage))
      logger.write_string(")")
    }
    Error(s) => {
      logger.write_string("Error(")
      logger.write_string(s)
      logger.write_string(")")
    }
  }
}

///|
/// StreamHandler receives streaming events.
pub(all) struct StreamHandler {
  on_event : (StreamEvent) -> Unit
}
