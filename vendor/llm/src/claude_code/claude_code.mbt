///|
pub struct ClaudeCodeProvider {
  model : String
  system_prompt : String
}

///|
pub fn ClaudeCodeProvider::new(
  model? : String = "",
  system_prompt? : String = "",
) -> ClaudeCodeProvider {
  { model, system_prompt }
}

///|
fn get_str(j : Json, field : String, default : String) -> String {
  match @llm.json_get_string(j, field) {
    Some(s) => s
    None => default
  }
}

///|
/// Parse a single JSONL line from Claude Code CLI output.
pub fn parse_claude_code_line(line : String) -> @llm.StreamEvent? {
  let json = @json.parse(line) catch { _ => return None }
  let event_type = get_str(json, "type", "")
  match event_type {
    "assistant" =>
      // Extract text content from the message
      match @llm.json_get_object(json, "message") {
        Some(msg) =>
          match @llm.json_get_array(msg, "content") {
            Some(content) => {
              let buf = StringBuilder::new()
              for block in content {
                let block_type = get_str(block, "type", "")
                if block_type == "text" {
                  buf.write_string(get_str(block, "text", ""))
                }
              }
              let text = buf.to_string()
              if !text.is_empty() {
                Some(@llm.StreamEvent::TextDelta(text))
              } else {
                None
              }
            }
            None => None
          }
        None => None
      }
    "result" => {
      // Result event indicates completion
      let finish_reason = @llm.FinishReason::Stop
      let usage : @llm.Usage? = match @llm.json_get_object(json, "usage") {
        Some(u) => {
          let input_tokens = match @llm.json_get_int(u, "input_tokens") {
            Some(n) => n
            None => 0
          }
          let output_tokens = match @llm.json_get_int(u, "output_tokens") {
            Some(n) => n
            None => 0
          }
          Some(@llm.Usage::{ input_tokens, output_tokens })
        }
        None => None
      }
      Some(@llm.StreamEvent::MessageEnd(finish_reason~, usage~))
    }
    "error" => {
      let msg = get_str(json, "error", "Unknown error")
      Some(@llm.StreamEvent::Error(msg))
    }
    _ => None
  }
}

///|
pub impl @llm.Provider for ClaudeCodeProvider with fn stream(
  self,
  messages,
  _tools,
  handler,
) {
  // Build the prompt from messages
  let prompt = StringBuilder::new()
  for msg in messages {
    let text = msg.get_text()
    if !text.is_empty() {
      prompt.write_string(text)
      prompt.write_string("\n")
    }
  }
  let prompt_str = prompt.to_string()
  // Build args
  let args : Array[String] = [
    "-p", prompt_str, "--output-format", "stream-json", "--verbose",
  ]
  if !self.system_prompt.is_empty() {
    args.push("--system-prompt")
    args.push(self.system_prompt)
  }
  if !self.model.is_empty() {
    args.push("--model")
    args.push(self.model)
  }
  let args_json = Json::array(args.map(fn(s) { ToJson::to_json(s) }))
  (handler.on_event)(@llm.StreamEvent::MessageStart)
  @ffi.exec_stream(
    "claude",
    args_json.stringify(),
    fn(line) {
      match parse_claude_code_line(line) {
        Some(event) => (handler.on_event)(event)
        None => ()
      }
    },
    fn() {  },
    fn(error) { (handler.on_event)(@llm.StreamEvent::Error(error)) },
  )
}

///|
pub impl @llm.Provider for ClaudeCodeProvider with fn name(_self) -> String {
  "claude_code"
}
