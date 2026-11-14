///|
/// Provider is the core trait for LLM providers.
pub(open) trait Provider {
  /// Send a streaming request to the LLM.
  fn stream(Self, Array[Message], Array[ToolDef], StreamHandler) -> Unit
  /// Get the provider name.
  fn name(Self) -> String
}

///|
/// BoxedProvider wraps a Provider for dynamic dispatch.
pub struct BoxedProvider {
  inner : &Provider
}

///|
pub fn BoxedProvider::new(provider : &Provider) -> BoxedProvider {
  { inner: provider }
}

///|
pub fn BoxedProvider::stream(
  self : BoxedProvider,
  messages : Array[Message],
  tools : Array[ToolDef],
  handler : StreamHandler,
) -> Unit {
  self.inner.stream(messages, tools, handler)
}

///|
pub fn BoxedProvider::name(self : BoxedProvider) -> String {
  self.inner.name()
}

///|
/// ProviderConfig holds common configuration for providers.
pub(all) struct ProviderConfig {
  api_key : String
  model : String
  max_tokens : Int
  system_prompt : String
  base_url : String
  timeout_sec : Int
  max_retries : Int
  retry_delay_ms : Int
}

///|
/// Create a ProviderConfig with defaults.
pub fn ProviderConfig::new(
  api_key : String,
  model : String,
  base_url : String,
  max_tokens? : Int = 4096,
  system_prompt? : String = "",
  timeout_sec? : Int = 300,
  max_retries? : Int = 3,
  retry_delay_ms? : Int = 1000,
) -> ProviderConfig {
  {
    api_key,
    model,
    max_tokens,
    system_prompt,
    base_url,
    timeout_sec,
    max_retries,
    retry_delay_ms,
  }
}

///|
/// Collect all text from a streaming provider call into a single string.
pub fn collect_text(
  provider : &Provider,
  messages : Array[Message],
  tools? : Array[ToolDef] = [],
) -> String {
  let buf = StringBuilder::new()
  let handler : StreamHandler = {
    on_event: fn(event) {
      match event {
        TextDelta(s) => buf.write_string(s)
        _ => ()
      }
    },
  }
  provider.stream(messages, tools, handler)
  buf.to_string()
}

///|
/// CollectResult holds the full result of a collected stream.
pub(all) struct CollectResult {
  text : String
  tool_calls : Array[ToolCall]
  finish_reason : FinishReason
  usage : Usage?
}

///|
/// Collect full response including text, tool calls, finish reason, and usage.
pub fn collect(
  provider : &Provider,
  messages : Array[Message],
  tools? : Array[ToolDef] = [],
) -> CollectResult {
  let text_buf = StringBuilder::new()
  let tool_calls : Array[ToolCall] = []
  let finish_reason : Ref[FinishReason] = { val: Stop }
  let usage : Ref[Usage?] = { val: None }
  let handler : StreamHandler = {
    on_event: fn(event) {
      match event {
        TextDelta(s) => text_buf.write_string(s)
        ToolCallEnd(id~, name~, input~) => tool_calls.push({ id, name, input })
        MessageEnd(finish_reason=fr, usage=u) => {
          finish_reason.val = fr
          usage.val = u
        }
        _ => ()
      }
    },
  }
  provider.stream(messages, tools, handler)
  {
    text: text_buf.to_string(),
    tool_calls,
    finish_reason: finish_reason.val,
    usage: usage.val,
  }
}

///|
/// Estimate token count for a message (rough: ~4 chars per token).
pub fn Message::estimate_tokens(self : Message) -> Int {
  let text = self.get_text()
  (text.length() + 3) / 4
}

///|
/// Truncate messages to fit within a token budget.
/// Keeps system messages and the last N messages within budget.
pub fn truncate_messages(
  messages : Array[Message],
  max_tokens : Int,
) -> Array[Message] {
  // Always keep system messages
  let system_msgs : Array[Message] = []
  let other_msgs : Array[Message] = []
  for msg in messages {
    if msg.role == System {
      system_msgs.push(msg)
    } else {
      other_msgs.push(msg)
    }
  }
  let mut budget = max_tokens
  for msg in system_msgs {
    budget -= msg.estimate_tokens()
  }
  if budget <= 0 {
    return system_msgs
  }
  // Take messages from the end until budget is exhausted
  let kept : Array[Message] = []
  for i = other_msgs.length() - 1; i >= 0; i = i - 1 {
    let cost = other_msgs[i].estimate_tokens()
    if budget - cost < 0 {
      break
    }
    budget -= cost
    kept.push(other_msgs[i])
  }
  // Reverse to restore order
  let result : Array[Message] = []
  for msg in system_msgs {
    result.push(msg)
  }
  for i = kept.length() - 1; i >= 0; i = i - 1 {
    result.push(kept[i])
  }
  result
}
