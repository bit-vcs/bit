///|
test "parse_claude_code_line - assistant text" {
  let line =
    #|{"type":"assistant","message":{"content":[{"type":"text","text":"Hello!"}]}}
  let event = parse_claude_code_line(line)
  match event {
    Some(@llm.StreamEvent::TextDelta(text)) =>
      @debug.debug_inspect(
        text,
        content=(
          #|"Hello!"
        ),
      )
    _ => fail("expected TextDelta")
  }
}

///|
test "parse_claude_code_line - result" {
  let line =
    #|{"type":"result","result":"done","usage":{"input_tokens":100,"output_tokens":50}}
  let event = parse_claude_code_line(line)
  match event {
    Some(@llm.StreamEvent::MessageEnd(finish_reason~, usage~)) => {
      @debug.debug_inspect(finish_reason, content="Stop")
      match usage {
        Some(u) => {
          @debug.debug_inspect(u.input_tokens, content="100")
          @debug.debug_inspect(u.output_tokens, content="50")
        }
        None => fail("expected usage")
      }
    }
    _ => fail("expected MessageEnd")
  }
}

///|
test "parse_claude_code_line - error" {
  let line =
    #|{"type":"error","error":"permission denied"}
  let event = parse_claude_code_line(line)
  match event {
    Some(@llm.StreamEvent::Error(msg)) =>
      @debug.debug_inspect(
        msg,
        content=(
          #|"permission denied"
        ),
      )
    _ => fail("expected Error")
  }
}

///|
test "parse_claude_code_line - invalid json" {
  let event = parse_claude_code_line("not json")
  @debug.debug_inspect(event is None, content="true")
}

///|
test "parse_claude_code_line - unknown type" {
  let line =
    #|{"type":"system","data":"something"}
  let event = parse_claude_code_line(line)
  @debug.debug_inspect(event is None, content="true")
}

///|
test "parse_claude_code_line - result without usage" {
  let line =
    #|{"type":"result","result":"done"}
  let event = parse_claude_code_line(line)
  match event {
    Some(@llm.StreamEvent::MessageEnd(finish_reason~, usage~)) => {
      @debug.debug_inspect(finish_reason, content="Stop")
      @debug.debug_inspect(usage is None, content="true")
    }
    _ => fail("expected MessageEnd")
  }
}
