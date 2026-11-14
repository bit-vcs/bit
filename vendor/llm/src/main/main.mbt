///|
/// MockProvider that replays pre-defined SSE event sequences.
priv struct MockProvider {
  responses : Array[Array[@llm.StreamEvent]]
  mut call_count : Int
}

///|
impl @llm.Provider for MockProvider with fn stream(
  self,
  _messages,
  _tools,
  handler,
) {
  if self.call_count < self.responses.length() {
    let events = self.responses[self.call_count]
    self.call_count += 1
    for event in events {
      (handler.on_event)(event)
    }
  }
}

///|
impl @llm.Provider for MockProvider with fn name(_self) -> String {
  "mock"
}

///|
fn main {
  println("=== Mock SSE Stream Debug ===")
  println("")
  // Test 1: Simple text streaming
  println("--- Test 1: Text streaming ---")
  test_text_stream() catch {
    e => println("[FAIL] " + e.to_string())
  }
  println("")
  // Test 2: Tool call streaming (delta accumulation)
  println("--- Test 2: Tool call streaming ---")
  test_tool_call_stream() catch {
    e => println("[FAIL] " + e.to_string())
  }
  println("")
  // Test 3: Agent loop with mock
  println("--- Test 3: Agent loop with tool execution ---")
  test_agent_loop() catch {
    e => println("[FAIL] " + e.to_string())
  }
  println("")
  println("=== All mock tests passed ===")
}

///|
fn test_text_stream() -> Unit raise {
  let provider : MockProvider = {
    responses: [
      [
        @llm.StreamEvent::MessageStart,
        @llm.StreamEvent::TextDelta("Hello"),
        @llm.StreamEvent::TextDelta(", "),
        @llm.StreamEvent::TextDelta("world!"),
        @llm.StreamEvent::MessageEnd(
          finish_reason=@llm.FinishReason::Stop,
          usage=Some(@llm.Usage::{ input_tokens: 10, output_tokens: 3 }),
        ),
      ],
    ],
    call_count: 0,
  }
  let events : Array[String] = []
  let text_buf = StringBuilder::new()
  let handler : @llm.StreamHandler = {
    on_event: fn(event) {
      events.push(event.to_string())
      match event {
        @llm.StreamEvent::TextDelta(s) => text_buf.write_string(s)
        _ => ()
      }
    },
  }
  let messages : Array[@llm.Message] = [@llm.Message::user("hi")]
  let tools : Array[@llm.ToolDef] = []
  @llm.Provider::stream(provider, messages, tools, handler)
  // Verify events
  for e in events {
    println("  [event] " + e)
  }
  let full_text = text_buf.to_string()
  println("  [collected text] " + full_text)
  assert_eq(full_text, "Hello, world!")
  assert_eq(events.length(), 5)
  println("  [OK] 5 events, text = \"Hello, world!\"")
}

///|
fn test_tool_call_stream() -> Unit raise {
  let tool_input : Json = {
    "location": ToJson::to_json("Tokyo"),
    "unit": ToJson::to_json("celsius"),
  }
  let provider : MockProvider = {
    responses: [
      [
        @llm.StreamEvent::MessageStart,
        @llm.StreamEvent::ToolCallStart(id="call_1", name="get_weather"),
        @llm.StreamEvent::ToolCallDelta(
          id="call_1",
          input_delta="{\"location\":",
        ),
        @llm.StreamEvent::ToolCallDelta(
          id="call_1",
          input_delta="\"Tokyo\",\"unit\":\"celsius\"}",
        ),
        @llm.StreamEvent::ToolCallEnd(
          id="call_1",
          name="get_weather",
          input=tool_input,
        ),
        @llm.StreamEvent::MessageEnd(
          finish_reason=@llm.FinishReason::ToolUse,
          usage=Some(@llm.Usage::{ input_tokens: 20, output_tokens: 15 }),
        ),
      ],
    ],
    call_count: 0,
  }
  let tool_calls : Array[@llm.ToolCall] = []
  let handler : @llm.StreamHandler = {
    on_event: fn(event) {
      println("  [event] " + event.to_string())
      match event {
        @llm.StreamEvent::ToolCallEnd(id~, name~, input~) =>
          tool_calls.push({ id, name, input })
        _ => ()
      }
    },
  }
  let messages : Array[@llm.Message] = [
    @llm.Message::user("What's the weather in Tokyo?"),
  ]
  let tools : Array[@llm.ToolDef] = []
  @llm.Provider::stream(provider, messages, tools, handler)
  assert_eq(tool_calls.length(), 1)
  assert_eq(tool_calls[0].name, "get_weather")
  assert_eq(tool_calls[0].id, "call_1")
  println(
    "  [collected tool_call] " +
    tool_calls[0].name +
    " input=" +
    tool_calls[0].input.stringify(),
  )
  println("  [OK] 1 tool call captured")
}

///|
fn test_agent_loop() -> Unit raise {
  let provider : MockProvider = {
    responses: [
      // Step 0: model calls get_weather tool
      [
        @llm.StreamEvent::MessageStart,
        @llm.StreamEvent::ToolCallStart(id="call_1", name="get_weather"),
        @llm.StreamEvent::ToolCallEnd(id="call_1", name="get_weather", input={
          "city": ToJson::to_json("Tokyo"),
        }),
        @llm.StreamEvent::MessageEnd(
          finish_reason=@llm.FinishReason::ToolUse,
          usage=None,
        ),
      ],
      // Step 1: model returns final text
      [
        @llm.StreamEvent::MessageStart,
        @llm.StreamEvent::TextDelta("It's 25°C in Tokyo."),
        @llm.StreamEvent::MessageEnd(
          finish_reason=@llm.FinishReason::Stop,
          usage=Some(@llm.Usage::{ input_tokens: 50, output_tokens: 10 }),
        ),
      ],
    ],
    call_count: 0,
  }
  let registry = @llm.ToolRegistry::new()
  registry.register("get_weather", "Get weather", Json::null(), fn(input) {
    let city = match @llm.json_get_string(input, "city") {
      Some(c) => c
      None => "unknown"
    }
    "{\"temp\":25,\"city\":\"" + city + "\"}"
  })
  let messages : Array[@llm.Message] = [
    @llm.Message::user("What's the weather in Tokyo?"),
  ]
  let log : Array[String] = []
  @llm.run_agent(
    @llm.BoxedProvider::new(provider),
    registry,
    messages,
    @llm.MaxSteps(5),
    fn(e) {
      let s = match e {
        @llm.AgentEvent::Stream(evt) => "[stream] " + evt.to_string()
        @llm.AgentEvent::ToolExecute(name~, input~) =>
          "[tool:exec] " + name + " " + input.stringify()
        @llm.AgentEvent::ToolResult(name~, result~, ..) =>
          "[tool:result] " + name + " => " + result
        @llm.AgentEvent::StepComplete(step~) =>
          "[step] " + step.to_string() + " complete"
        @llm.AgentEvent::Done(reason~) => "[done] " + reason
      }
      log.push(s)
      println("  " + s)
    },
  )
  // Verify the conversation
  println("  [messages] " + messages.length().to_string() + " total")
  for i, msg in messages {
    println(
      "    [" +
      i.to_string() +
      "] " +
      msg.role.to_string() +
      ": " +
      msg.get_text(),
    )
  }
  assert_eq(messages.length(), 4)
  assert_eq(messages[0].role.to_string(), "user")
  assert_eq(messages[1].role.to_string(), "assistant")
  assert_eq(messages[2].role.to_string(), "tool")
  assert_eq(messages[3].role.to_string(), "assistant")
  assert_eq(messages[3].get_text(), "It's 25°C in Tokyo.")
  println("  [OK] Agent loop: 2 steps, tool call + final text")
}
