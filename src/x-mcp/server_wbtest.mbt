///| Whitebox tests for MCP request dispatch

///|
test "build_tool_defs returns empty tools" {
  let defs = mcp_tool_defs().stringify()
  assert_true(defs.contains("\"tools\""))
}

///|
test "process_message returns parse error for invalid json" {
  let resp = mcp_process_message("{invalid json")
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
  let resp = mcp_process_message(req)
  assert_true(resp is None)
}

///|
test "process_message initialize returns capability response" {
  let req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}"
  let resp = mcp_process_message(req)
  match resp {
    Some(s) => {
      assert_true(s.contains("\"jsonrpc\":\"2.0\""))
      assert_true(s.contains("\"protocolVersion\":\"2024-11-05\""))
    }
    None => assert_true(false)
  }
}

///|
test "process_message unknown tool returns error" {
  let req = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"unknown\",\"arguments\":{}}}"
  let resp = mcp_process_message(req)
  match resp {
    Some(s) => {
      assert_true(s.contains("\"error\""))
      assert_true(s.contains("-32601"))
    }
    None => assert_true(false)
  }
}

///|
test "mcp_dispatch_request exposes tools/list handler" {
  let resp = mcp_dispatch_request(
    "tools/list",
    Json::number(9.0),
    Json::object({}),
  )
  assert_true(resp.contains("\"tools\""))
}
