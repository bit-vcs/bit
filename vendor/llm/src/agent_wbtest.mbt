///|
test "agent - simple text response (no tools)" {
  let provider : MockProvider = {
    responses: [
      [
        MessageStart,
        TextDelta("Hello!"),
        MessageEnd(finish_reason=Stop, usage=None),
      ],
    ],
    call_count: 0,
  }
  let registry = ToolRegistry::new()
  let messages : Array[Message] = [Message::user("hi")]
  let events : Array[String] = []
  run_agent(BoxedProvider::new(provider), registry, messages, MaxSteps(5), fn(
    e,
  ) {
    match e {
      Done(reason~) => events.push("done:" + reason)
      Stream(TextDelta(s)) => events.push("text:" + s)
      _ => ()
    }
  })
  let expected =
    #|["text:Hello!", "done:no_tool_calls"]
  @debug.debug_inspect(events, content=expected)
  // Messages should include the assistant response
  @debug.debug_inspect(messages.length(), content="2")
  @debug.debug_inspect(
    messages[1].get_text(),
    content=(
      #|"Hello!"
    ),
  )
}

///|
test "agent - tool call loop" {
  let provider : MockProvider = {
    responses: [
      // First response: tool call
      [
        MessageStart,
        ToolCallStart(id="call_1", name="greet"),
        ToolCallEnd(id="call_1", name="greet", input={
          "name": ToJson::to_json("Alice"),
        }),
        MessageEnd(finish_reason=ToolUse, usage=None),
      ],
      // Second response: text after tool result
      [
        MessageStart,
        TextDelta("Greeted Alice!"),
        MessageEnd(finish_reason=Stop, usage=None),
      ],
    ],
    call_count: 0,
  }
  let registry = ToolRegistry::new()
  registry.register("greet", "Greet someone", Json::null(), fn(input) {
    let name = match json_get_string(input, "name") {
      Some(n) => n
      None => "world"
    }
    "Hello, " + name + "!"
  })
  let messages : Array[Message] = [Message::user("greet Alice")]
  let events : Array[String] = []
  run_agent(BoxedProvider::new(provider), registry, messages, MaxSteps(5), fn(
    e,
  ) {
    match e {
      ToolExecute(name~, ..) => events.push("exec:" + name)
      ToolResult(name~, result~, ..) =>
        events.push("result:" + name + "=" + result)
      StepComplete(step~) => events.push("step:" + step.to_string())
      Done(reason~) => events.push("done:" + reason)
      _ => ()
    }
  })
  @debug.debug_inspect(
    events,
    content=(
      #|[
      #|  "exec:greet",
      #|  "result:greet=Hello, Alice!",
      #|  "step:0",
      #|  "done:no_tool_calls",
      #|]
    ),
  )
}

///|
test "agent - max steps" {
  // Provider always returns tool calls, so agent should stop at max_steps
  let make_tool_response : () -> Array[StreamEvent] = fn() {
    [
      MessageStart,
      ToolCallStart(id="call_1", name="loop_tool"),
      ToolCallEnd(id="call_1", name="loop_tool", input=Json::null()),
      MessageEnd(finish_reason=ToolUse, usage=None),
    ]
  }
  let provider : MockProvider = {
    responses: [
      make_tool_response(),
      make_tool_response(),
      make_tool_response(),
    ],
    call_count: 0,
  }
  let registry = ToolRegistry::new()
  registry.register("loop_tool", "A tool", Json::null(), fn(_input) { "ok" })
  let messages : Array[Message] = [Message::user("loop")]
  let done_reason = Ref("")
  run_agent(BoxedProvider::new(provider), registry, messages, MaxSteps(2), fn(
    e,
  ) {
    match e {
      Done(reason~) => done_reason.val = reason
      _ => ()
    }
  })
  @debug.debug_inspect(
    done_reason.val,
    content=(
      #|"max_steps"
    ),
  )
}

///|
test "collect_text - simple text" {
  let provider : MockProvider = {
    responses: [
      [
        MessageStart,
        TextDelta("Hello"),
        TextDelta(", world!"),
        MessageEnd(finish_reason=Stop, usage=None),
      ],
    ],
    call_count: 0,
  }
  let messages : Array[Message] = [Message::user("hi")]
  let text = collect_text(provider, messages)
  @debug.debug_inspect(
    text,
    content=(
      #|"Hello, world!"
    ),
  )
}

///|
test "collect - full response" {
  let provider : MockProvider = {
    responses: [
      [
        MessageStart,
        TextDelta("Result: "),
        TextDelta("42"),
        ToolCallEnd(id="call_1", name="calc", input={ "expr": ToJson::to_json("6*7") }),
        MessageEnd(
          finish_reason=Stop,
          usage=Some(Usage::{ input_tokens: 10, output_tokens: 5 }),
        ),
      ],
    ],
    call_count: 0,
  }
  let messages : Array[Message] = [Message::user("calc")]
  let result = collect(provider, messages)
  @debug.debug_inspect(
    result.text,
    content=(
      #|"Result: 42"
    ),
  )
  @debug.debug_inspect(result.tool_calls.length(), content="1")
  @debug.debug_inspect(
    result.tool_calls[0].name,
    content=(
      #|"calc"
    ),
  )
  @debug.debug_inspect(result.finish_reason, content="Stop")
  @debug.debug_inspect(
    result.usage,
    content=(
      #|Some({ input_tokens: 10, output_tokens: 5 })
    ),
  )
}

///|
test "truncate_messages - within budget" {
  let msgs : Array[Message] = [Message::user("hi"), Message::assistant("hello")]
  let result = truncate_messages(msgs, 1000)
  @debug.debug_inspect(result.length(), content="2")
}

///|
test "truncate_messages - keeps system messages" {
  let msgs : Array[Message] = [
    Message::system("You are helpful"),
    Message::user("first"),
    Message::user("second"),
    Message::user("third"),
  ]
  let result = truncate_messages(msgs, 5)
  // Should keep system + only last messages within budget
  assert_true(result.length() > 0)
  @debug.debug_inspect(
    result[0].role,
    content=(
      #|System
    ),
  )
}

///|
test "truncate_messages - drops old messages" {
  let msgs : Array[Message] = [
    Message::user("a very long first message that takes many tokens"),
    Message::user("also a long second message with many tokens too"),
    Message::user("short"),
  ]
  // Budget only fits the last message
  let result = truncate_messages(msgs, 3)
  @debug.debug_inspect(result.length(), content="1")
  @debug.debug_inspect(
    result[0].get_text(),
    content=(
      #|"short"
    ),
  )
}

///|
test "SchemaBuilder - basic" {
  let schema = SchemaBuilder::new()
    .string("name", "The name", required=true)
    .number("age", "The age")
    .boolean("active", "Is active", required=true)
    .build()
  let s = schema.stringify()
  // Check it's valid JSON with expected structure
  let parsed = @json.parse(s) catch { _ => panic() }
  @debug.debug_inspect(
    json_get_string(parsed, "type"),
    content="Some(\"object\")",
  )
  let props = json_get_object(parsed, "properties")
  assert_true(!(props is None))
  let required = json_get_array(parsed, "required")
  match required {
    Some(arr) => @debug.debug_inspect(arr.length(), content="2")
    None => panic()
  }
}

///|
test "SchemaBuilder - string_enum" {
  let schema = SchemaBuilder::new()
    .string_enum(
      "unit",
      "Temperature unit",
      ["celsius", "fahrenheit"],
      required=true,
    )
    .build()
  let s = schema.stringify()
  let parsed = @json.parse(s) catch { _ => panic() }
  let props = json_get_object(parsed, "properties")
  match props {
    Some(p) => {
      let unit = json_get_object(p, "unit")
      assert_true(!(unit is None))
    }
    None => panic()
  }
}

///|
test "SchemaBuilder - array type" {
  let schema = SchemaBuilder::new()
    .array("tags", "List of tags", "string", required=true)
    .integer("count", "Number of items")
    .build()
  let s = schema.stringify()
  let parsed = @json.parse(s) catch { _ => panic() }
  let props = json_get_object(parsed, "properties")
  assert_true(!(props is None))
}

///|
test "estimate_tokens" {
  let msg = Message::user("hello world")
  // "hello world" = 11 chars, (11+3)/4 = 3
  @debug.debug_inspect(msg.estimate_tokens(), content="3")
}
