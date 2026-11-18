// Streaming API tests

///|
async test "stream: GET read_some" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write(b"chunk1")
      conn.flush_partial_data()
      conn.write(b"chunk2")
      conn.end_response()
    })
    let (resp, stream) = @http.get_stream(
      "http://127.0.0.1:\{addr.port.to_int()}/stream",
    )
    defer stream.close()
    assert_eq(resp.code, 200)
    let buf = StringBuilder()
    for ;; {
      match stream.read_some() {
        Some(chunk) =>
          for i = 0; i < chunk.length(); i = i + 1 {
            buf.write_char(chunk[i].to_int().unsafe_to_char())
          }
        None => break
      }
    }
    assert_eq(buf.to_string(), "chunk1chunk2")
  })
}

///|
async test "stream: GET read_all" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write(b"full body content")
      conn.end_response()
    })
    let (resp, stream) = @http.get_stream(
      "http://127.0.0.1:\{addr.port.to_int()}/all",
    )
    defer stream.close()
    assert_eq(resp.code, 200)
    let body : &@data.Data = stream.read_all()
    let body_str : &@data.Data = body
    assert_eq(body_str.text(), "full body content")
  })
}

///|
async test "stream: POST with body" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      guard req.meth is Post else { fail("expected POST") }
      let body : &@data.Data = conn.read_all()
      conn.send_response(200, "OK")
      conn.write(b"echo:")
      conn.flush_partial_data()
      conn.write_string(body.text())
      conn.end_response()
    })
    let post_body : String = "stream data"
    let stream = @http.post_stream(
      "http://127.0.0.1:\{addr.port.to_int()}/post",
    )
    defer stream.close()
    stream.write(post_body)
    let resp = stream.end_request()
    assert_eq(resp.code, 200)
    let body : &@data.Data = stream.read_all()
    assert_eq(body.text(), "echo:stream data")
  })
}

///|
async test "stream: SSE-like chunked response" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      let extra : Map[@async_http.CaseInsensitiveString, String] = {
        "Content-Type": "text/event-stream",
      }
      conn.send_response(200, "OK", extra_headers=extra)
      // Simulate SSE events
      conn.write(b"data: event1\n\n")
      conn.flush_partial_data()
      conn.write(b"data: event2\n\n")
      conn.flush_partial_data()
      conn.write(b"data: event3\n\n")
      conn.end_response()
    })
    let (resp, stream) = @http.get_stream(
      "http://127.0.0.1:\{addr.port.to_int()}/events",
    )
    defer stream.close()
    assert_eq(resp.code, 200)
    assert_eq(
      resp.headers.get("content-type").unwrap_or(""),
      "text/event-stream",
    )
    // Read all chunks and verify complete SSE data
    let buf = StringBuilder()
    for ;; {
      match stream.read_some() {
        Some(chunk) =>
          for i = 0; i < chunk.length(); i = i + 1 {
            buf.write_char(chunk[i].to_int().unsafe_to_char())
          }
        None => break
      }
    }
    let result = buf.to_string()
    assert_true(result.contains("data: event1"))
    assert_true(result.contains("data: event2"))
    assert_true(result.contains("data: event3"))
  })
}

///|
async test "stream: OpenAI-like POST SSE" {
  // Simulates OpenAI chat completions streaming:
  // POST with JSON body + Authorization header → SSE response
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      // Verify request
      guard req.meth is Post else { fail("expected POST") }
      let auth = req.headers.get("authorization").unwrap_or("")
      guard auth == "Bearer test-key" else { fail("bad auth: " + auth) }
      let ct = req.headers.get("content-type").unwrap_or("")
      guard ct == "application/json" else { fail("bad content-type: " + ct) }
      let body : &@data.Data = conn.read_all()
      let body_text = body.text()
      guard body_text.contains("\"stream\":true") ||
        body_text.contains("\"stream\": true") else {
        fail("body missing stream:true")
      }
      // Send SSE response
      let extra : Map[@async_http.CaseInsensitiveString, String] = {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
      }
      conn.send_response(200, "OK", extra_headers=extra)
      // Simulate streaming tokens
      conn.write_string(
        "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
      )
      conn.flush_partial_data()
      conn.write_string(
        "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n",
      )
      conn.flush_partial_data()
      conn.write(b"data: [DONE]\n\n")
      conn.end_response()
    })
    let headers : Map[String, String] = {
      "Authorization": "Bearer test-key",
      "Content-Type": "application/json",
    }
    let body : String = "{\"model\":\"gpt-4\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"stream\":true}"
    let stream = @http.post_stream(
      "http://127.0.0.1:\{addr.port.to_int()}/v1/chat/completions",
      headers~,
    )
    stream.write(body)
    let resp = stream.end_request()
    defer stream.close()
    assert_eq(resp.code, 200)
    assert_eq(
      resp.headers.get("content-type").unwrap_or(""),
      "text/event-stream",
    )
    // Parse SSE events from stream
    let events : Array[String] = []
    let buf = StringBuilder()
    for ;; {
      match stream.read_some() {
        Some(chunk) =>
          for i = 0; i < chunk.length(); i = i + 1 {
            buf.write_char(chunk[i].to_int().unsafe_to_char())
          }
        None => break
      }
    }
    // Split by double newline to get events
    let raw = buf.to_string()
    let lines = raw.split("\n")
    for line in lines {
      let trimmed = line.to_owned()
      if trimmed.has_prefix("data: ") {
        events.push(trimmed.exact_view(start=6).to_owned())
      }
    }
    assert_eq(events.length(), 3)
    assert_true(events[0].contains("Hello"))
    assert_true(events[1].contains(" world"))
    assert_eq(events[2], "[DONE]")
  })
}

///|
async test "stream: response headers available before body" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      let extra : Map[@async_http.CaseInsensitiveString, String] = {
        "X-Stream-Id": "abc123",
      }
      conn.send_response(200, "OK", extra_headers=extra)
      conn.write(b"body")
      conn.end_response()
    })
    let (resp, stream) = @http.get_stream(
      "http://127.0.0.1:\{addr.port.to_int()}/headers",
    )
    defer stream.close()
    // Headers are available immediately, before reading body
    assert_eq(resp.code, 200)
    assert_eq(resp.headers.get("x-stream-id").unwrap_or(""), "abc123")
    // Now read body
    let body : &@data.Data = stream.read_all()
    let body_data : &@data.Data = body
    assert_eq(body_data.text(), "body")
  })
}

///|
async test "smoke: stream matches upstream get_stream" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        ignore(conn.read_request())
        conn.skip_request_body()
        conn.send_response(200, "OK")
        conn.write(b"part1\n")
        conn.flush_partial_data()
        conn.write(b"part2\n")
        conn.end_response()
        conn.close()
      }
    })
    let port = addr.port.to_int()
    // Upstream: get_stream + read_some
    let (upstream_resp, upstream_client) = @async_http.get_stream(
      "http://127.0.0.1:\{port}/test",
    )
    defer upstream_client.close()
    let upstream_buf = StringBuilder()
    while upstream_client.read() is Some(chunk) {
      for i = 0; i < chunk.length(); i = i + 1 {
        upstream_buf.write_char(chunk[i].to_int().unsafe_to_char())
      }
    }
    // Wrapper: get_stream + read_some
    let (wrapper_resp, wrapper_stream) = @http.get_stream(
      "http://127.0.0.1:\{port}/test",
    )
    defer wrapper_stream.close()
    let wrapper_buf = StringBuilder()
    for ;; {
      match wrapper_stream.read_some() {
        Some(chunk) =>
          for i = 0; i < chunk.length(); i = i + 1 {
            wrapper_buf.write_char(chunk[i].to_int().unsafe_to_char())
          }
        None => break
      }
    }
    // Compare
    assert_eq(upstream_resp.code, wrapper_resp.code)
    assert_eq(upstream_buf.to_string(), wrapper_buf.to_string())
    assert_eq(upstream_buf.to_string(), "part1\npart2\n")
  })
}

// Non-streaming API tests

///|
async test "http GET" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      conn.skip_request_body()
      guard req.meth is Get else { fail("expected GET") }
      conn.send_response(200, "OK")
      conn.write(b"hello from server")
      conn.end_response()
    })
    let (resp, body) = @http.get("http://127.0.0.1:\{addr.port.to_int()}/test")
    assert_eq(resp.code, 200)
    assert_eq(resp.reason, "OK")
    assert_eq(body.text(), "hello from server")
  })
}

///|
async test "http POST with body" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      guard req.meth is Post else { fail("expected POST") }
      let body : &@data.Data = conn.read_all()
      conn.send_response(201, "Created")
      conn.write_string("received: " + body.text())
      conn.end_response()
    })
    let post_body : String = "test data"
    let (resp, body) = @http.post(
      "http://127.0.0.1:\{addr.port.to_int()}/items",
      post_body,
    )
    assert_eq(resp.code, 201)
    assert_eq(resp.reason, "Created")
    assert_eq(body.text(), "received: test data")
  })
}

///|
async test "http PUT with body" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      guard req.meth is Put else { fail("expected PUT") }
      let body : &@data.Data = conn.read_all()
      conn.send_response(200, "OK")
      conn.write_string("updated: " + body.text())
      conn.end_response()
    })
    let put_body : String = "updated data"
    let (resp, body) = @http.put(
      "http://127.0.0.1:\{addr.port.to_int()}/items/1",
      put_body,
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "updated: updated data")
  })
}

///|
async test "http GET with custom headers" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      conn.skip_request_body()
      let auth = req.headers.get("authorization").unwrap_or("none")
      conn.send_response(200, "OK")
      conn.write_string("auth: " + auth)
      conn.end_response()
    })
    let headers : Map[String, String] = { "Authorization": "Bearer token123" }
    let (resp, body) = @http.get(
      "http://127.0.0.1:\{addr.port.to_int()}/secure",
      headers~,
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "auth: Bearer token123")
  })
}

///|
async test "client and server preserve string headers across native requests" {
  @async.with_task_group(group => {
    let server = @http.Server::new(host="127.0.0.1", port=0, headers={
      "X-SeRvEr": "default",
    })
    defer server.close()
    group.spawn_bg(() => {
      let (conn, _) = server.accept()
      defer conn.close()
      for _ in 0..<3 {
        let req = conn.read_request()
        assert_eq(req.headers.get("x-client"), Some("default"))
        assert_eq(req.headers.get("x-request"), Some("per-request"))
        conn.skip_request_body()
        conn.send_response(200, "OK", extra_headers={
          "X-ReSpOnSe": "per-response",
        })
        conn.write(b"ok")
        conn.end_response()
      }
    })
    let client = @http.Client::new("http://127.0.0.1:\{server.port()}", headers={
      "X-ClIeNt": "default",
    })
    defer client.close()
    let extra_headers : Map[String, String] = { "X-ReQuEsT": "per-request" }
    for meth in [@http.Get, @http.Post, @http.Put] {
      let resp = match meth {
        @http.Post => client.post("/", "body", extra_headers~)
        @http.Put => client.put("/", "body", extra_headers~)
        _ => client.get("/", extra_headers~)
      }
      assert_eq(resp.code, 200)
      assert_eq(resp.headers.get("x-server"), Some("default"))
      assert_eq(resp.headers.get("x-response"), Some("per-response"))
      assert_eq(client.read_all().text(), "ok")
    }
  })
}

///|
async test "http response headers" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      let extra_headers : Map[@async_http.CaseInsensitiveString, String] = {
        "X-Custom": "custom-value",
        "Content-Type": "text/plain",
      }
      conn.send_response(200, "OK", extra_headers~)
      conn.write(b"ok")
      conn.end_response()
    })
    let (resp, _) = @http.get("http://127.0.0.1:\{addr.port.to_int()}/")
    assert_eq(resp.code, 200)
    assert_eq(resp.headers.get("x-custom").unwrap_or(""), "custom-value")
    assert_eq(resp.headers.get("content-type").unwrap_or(""), "text/plain")
  })
}

///|
async test "http 404 response" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(404, "Not Found")
      conn.write(b"not found")
      conn.end_response()
    })
    let (resp, body) = @http.get(
      "http://127.0.0.1:\{addr.port.to_int()}/missing",
    )
    assert_eq(resp.code, 404)
    assert_eq(resp.reason, "Not Found")
    assert_eq(body.text(), "not found")
  })
}

///|
async test "http empty body" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(204, "No Content")
      conn.end_response()
    })
    let (resp, body) = @http.get("http://127.0.0.1:\{addr.port.to_int()}/empty")
    assert_eq(resp.code, 204)
    assert_eq(body.text(), "")
  })
}

///|
async test "http unicode body" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write_string("こんにちは世界")
      conn.end_response()
    })
    let (resp, body) = @http.get(
      "http://127.0.0.1:\{addr.port.to_int()}/unicode",
    )
    assert_eq(resp.code, 200)
    assert_eq(
      body.text(),
      "\u{3053}\u{3093}\u{306B}\u{3061}\u{306F}\u{4E16}\u{754C}",
    )
  })
}

///|
async test "smoke: GET matches upstream" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      // Handle two requests: upstream then wrapper
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let req = conn.read_request()
        conn.skip_request_body()
        conn.send_response(200, "OK")
        conn.write_string("path=" + req.path)
        conn.end_response()
        conn.close()
      }
    })
    let url = "http://127.0.0.1:\{addr.port.to_int()}/test"
    // Upstream
    let upstream_client = @async_http.ClientConnection(
      "http://127.0.0.1:\{addr.port.to_int()}",
    )
    defer upstream_client.close()
    upstream_client.request(Get, "/test")
    let upstream_resp = upstream_client.end_request()
    let upstream_body : &@data.Data = upstream_client.read_all()
    // Wrapper
    let (wrapper_resp, wrapper_body) = @http.get(url)
    // Compare
    assert_eq(upstream_resp.code, wrapper_resp.code)
    assert_eq(upstream_body.text(), wrapper_body.text())
    assert_eq(upstream_body.text(), "path=/test")
  })
}

///|
async test "smoke: POST matches upstream" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        ignore(conn.read_request())
        let body : &@data.Data = conn.read_all()
        conn.send_response(201, "Created")
        conn.write_string("echo:" + body.text())
        conn.end_response()
        conn.close()
      }
    })
    let post_data : String = "payload"
    // Upstream
    let upstream_client = @async_http.ClientConnection(
      "http://127.0.0.1:\{addr.port.to_int()}",
    )
    defer upstream_client.close()
    upstream_client.request(Post, "/api")
    upstream_client.write(@utf8.encode(post_data)[:])
    let upstream_resp = upstream_client.end_request()
    let upstream_body : &@data.Data = upstream_client.read_all()
    // Wrapper
    let (wrapper_resp, wrapper_body) = @http.post(
      "http://127.0.0.1:\{addr.port.to_int()}/api",
      post_data,
    )
    // Compare
    assert_eq(upstream_resp.code, wrapper_resp.code)
    assert_eq(upstream_resp.reason, wrapper_resp.reason)
    assert_eq(upstream_body.text(), wrapper_body.text())
    assert_eq(upstream_body.text(), "echo:payload")
  })
}

///|
async test "client: generic request via Client::request" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      guard req.meth is Patch else { fail("expected PATCH") }
      assert_eq(req.path, "/generic")
      let request_body : &@data.Data = conn.read_all()
      conn.send_response(200, "OK")
      conn.write_string("seen:" + request_body.text())
      conn.end_response()
    })
    let client = @http.Client::new("http://127.0.0.1:\{addr.port.to_int()}")
    defer client.close()
    client.request(@http.RequestMethod::Patch, "/generic", extra_headers={
      "Content-Type": "text/plain",
    })
    client.write(b"payload")
    let resp = client.end_request()
    let body : &@data.Data = client.read_all()
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "seen:payload")
  })
}

///|
async test "http multi-part response" {
  // Adapted from upstream "request streaming" test
  // Server sends response in multiple writes, client receives full body
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write_string("part1-" + req.path + "\n")
      conn.flush_partial_data()
      conn.write_string("part2-" + req.path + "\n")
      conn.end_response()
    })
    let (resp, body) = @http.get("http://127.0.0.1:\{addr.port.to_int()}/multi")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "part1-/multi\npart2-/multi\n")
  })
}

///|
async test "http POST echo - request method and path" {
  // Adapted from upstream "request streaming": server echoes method+path
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 3; i = i + 1 {
        let (conn, _) = server.accept()
        let req = conn.read_request()
        let body : &@data.Data = conn.read_all()
        conn.send_response(200, "OK")
        conn.write_string(
          @debug.to_string(req.meth) + " " + req.path + " body=" + body.text(),
        )
        conn.end_response()
        conn.close()
      }
    })
    let port = addr.port.to_int()
    // GET
    let (_, get_body) = @http.get("http://127.0.0.1:\{port}/get")
    assert_eq(get_body.text(), "Get /get body=")
    // POST
    let post_data : String = "data1"
    let (_, post_body) = @http.post("http://127.0.0.1:\{port}/post", post_data)
    assert_eq(post_body.text(), "Post /post body=data1")
    // PUT
    let put_data : String = "data2"
    let (_, put_body) = @http.put("http://127.0.0.1:\{port}/put", put_data)
    assert_eq(put_body.text(), "Put /put body=data2")
  })
}

///|
async test "http multiple sequential requests" {
  // Adapted from upstream "request streaming": multiple requests on same server
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 5; i = i + 1 {
        let (conn, _) = server.accept()
        let req = conn.read_request()
        conn.skip_request_body()
        conn.send_response(200, "OK")
        conn.write_string("req-" + i.to_string() + "-" + req.path)
        conn.end_response()
        conn.close()
      }
    })
    let port = addr.port.to_int()
    for i = 0; i < 5; i = i + 1 {
      let (resp, body) = @http.get("http://127.0.0.1:\{port}/path\{i}")
      assert_eq(resp.code, 200)
      assert_eq(body.text(), "req-" + i.to_string() + "-/path" + i.to_string())
    }
  })
}

///|
async test "https request" {
  // Same as upstream "https request"
  let (_, result) = @http.get("https://www.example.org")
  assert_true(result.text().has_prefix("<!doctype html>"))
}

///|
async test "http request" {
  // Same as upstream "http request"
  let (_, result) = @http.get("http://www.example.org")
  assert_true(result.text().has_prefix("<!doctype html>"))
}

///|
async test "smoke: response headers match upstream" {
  @async.with_task_group(group => {
    let server = @async_http.Server(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        ignore(conn.read_request())
        conn.skip_request_body()
        let extra : Map[@async_http.CaseInsensitiveString, String] = {
          "X-Test": "value123",
        }
        conn.send_response(200, "OK", extra_headers=extra)
        conn.write(b"ok")
        conn.end_response()
        conn.close()
      }
    })
    // Upstream
    let upstream_client = @async_http.ClientConnection(
      "http://127.0.0.1:\{addr.port.to_int()}",
    )
    defer upstream_client.close()
    upstream_client.request(Get, "/")
    let upstream_resp = upstream_client.end_request()
    ignore(upstream_client.read_all())
    let upstream_header = upstream_resp.headers.get("x-test").unwrap_or("")
    // Wrapper
    let (wrapper_resp, _) = @http.get("http://127.0.0.1:\{addr.port.to_int()}/")
    let wrapper_header = wrapper_resp.headers.get("x-test").unwrap_or("")
    // Compare
    assert_eq(upstream_header, wrapper_header)
    assert_eq(upstream_header, "value123")
  })
}

///|
async test "server: addr and client_addr" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let listen_addr = server.addr()
    assert_eq(listen_addr.port, server.port())
    let seen_client_ports : Array[Int32] = []
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever(
        (_req, _body, conn) => {
          seen_client_ports.push(conn.client_addr().port)
          conn.send_response(200, "OK")
          conn.write(b"ok")
          conn.end_response()
        },
        max_connections=1,
      )
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{server.port()}/addr")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")
    assert_eq(seen_client_ports.length(), 1)
    assert_true(seen_client_ports[0] > 0)
  })
}

///|
async test "server: accept GET" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      let (conn, peer) = server.accept()
      let req = conn.read_request()
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write(req.path + "|" + peer.port.to_string())
      conn.end_response()
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/accept-path")
    assert_eq(resp.code, 200)
    let text = body.text()
    assert_true(text.has_prefix("/accept-path|"))
  })
}

///|
async test "passthrough mode remaining data" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let addr = server.addr()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      let (conn, _) = server.accept()
      ignore(conn.read_request())
      conn.enter_passthrough_mode()
      let rest : &@data.Data = conn.read_all()
      let data : &@data.Data = rest
      assert_eq(data.text(), "remaining data")
      conn.close()
    })
    let client = @socket.Tcp::connect(@socket.Addr::parse(addr.text))
    defer client.close()
    client.write(b"GET / HTTP/1.1\r\n\r\nremaining data")
  })
}
