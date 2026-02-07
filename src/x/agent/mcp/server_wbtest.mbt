///| Whitebox tests for MCP request dispatch

///|
test "build_tool_defs includes run_agent and run_orchestrator" {
  let defs = build_tool_defs().stringify()
  assert_true(defs.contains("\"run_agent\""))
  assert_true(defs.contains("\"run_orchestrator\""))
}

///|
test "process_message returns parse error for invalid json" {
  let resp = process_message("{invalid json")
  match resp {
    Some(s) => {
      assert_true(s.contains("\"error\""))
      assert_true(s.contains("-32700"))
    }
    None => assert_true(false)
  }
}

///|
test "process_message ignores initialized notification" {
  let req = "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\"}"
  let resp = process_message(req)
  assert_true(resp is None)
}

///|
test "process_message initialize returns capability response" {
  let req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}"
  let resp = process_message(req)
  match resp {
    Some(s) => {
      assert_true(s.contains("\"jsonrpc\":\"2.0\""))
      assert_true(s.contains("\"protocolVersion\":\"2024-11-05\""))
    }
    None => assert_true(false)
  }
}

///|
test "process_message unknown tool returns method-not-found" {
  let req = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"unknown\",\"arguments\":{}}}"
  let resp = process_message(req)
  match resp {
    Some(s) => {
      assert_true(s.contains("\"error\""))
      assert_true(s.contains("-32601"))
    }
    None => assert_true(false)
  }
}

///|
test "process_message run_agent validates required task" {
  let req = "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"run_agent\",\"arguments\":{}}}"
  let resp = process_message(req)
  match resp {
    Some(s) => {
      assert_true(s.contains("\"isError\":true"))
      assert_true(s.contains("task is required"))
    }
    None => assert_true(false)
  }
}
