///|
fn fixed_ascii(buf : FixedArray[Byte], len : Int32) -> String {
  let out = StringBuilder()
  for i in 0..<len {
    out.write_char(buf[i].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
async fn read_http_headers(conn : @x_socket.Tcp) -> String {
  let out = StringBuilder()
  let buf = FixedArray::make(1024, b'\x00')
  for ;; {
    let n = conn.read(buf)
    if n <= 0 {
      break
    }
    out.write_string(fixed_ascii(buf, n))
    if out.to_string().contains("\r\n\r\n") {
      break
    }
  }
  out.to_string()
}

///|
fn content_length_from_headers(headers : String) -> Int32 {
  for line in headers.split("\r\n") {
    let lower = line.to_lower()
    if lower.has_prefix("content-length:") {
      return @string.parse_int(line[15:].trim(), radix=10) catch { _ => 0 }
    }
  }
  0
}

///|
async fn read_http_request(conn : @x_socket.Tcp) -> String {
  let received = read_http_headers(conn)
  let len = content_length_from_headers(received)
  if len <= 0 {
    received
  } else {
    let already = match received.find("\r\n\r\n") {
      Some(pos) => received.length() - pos - 4
      None => 0
    }
    if already >= len {
      received
    } else {
      received + @utf8.decode(conn.read_exactly(len - already))
    }
  }
}

///|
async fn gzip_bytes(data : &@data.Data) -> Bytes {
  let mut result = b""
  @async.with_task_group(root => {
    let (r, w) = @io.memory_pipe()
    root.spawn_bg(() => {
      defer w.close()
      let enc = @gzip.Encoder(w)
      enc.write(data)
      enc.end()
    })
    defer r.close()
    result = r.read_all()
  })
  result
}

///|
async fn raw_request(
  meth : @http.RequestMethod,
  path : String,
  response : &@data.Data,
  hold_open_ms~ : Int32 = 0,
) -> (@http.Response, String, String) {
  let mut response_headers = @http.Response::{
    code: 0,
    reason: "",
    headers: {},
    cookies: [],
  }
  let mut body_text = ""
  let mut request_text = ""
  @async.with_task_group(root => {
    let server = @x_socket.TcpServer(@x_socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    root.spawn_bg(no_wait=true, allow_failure=true, () => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      request_text = read_http_request(conn)
      conn.write(response)
      if hold_open_ms > 0 {
        @async.sleep(hold_open_ms)
      }
    })
    let client = @http.Client::new("http://127.0.0.1:\{port}")
    defer client.close()
    client.request(meth, path)
    response_headers = client.end_request()
    body_text = client.read_all().text()
  })
  (response_headers, body_text, request_text)
}

///|
async fn raw_get(
  response : &@data.Data,
  hold_open_ms~ : Int32 = 0,
) -> (@http.Response, String, String) {
  raw_request(@http.Get, "/", response, hold_open_ms~)
}

///|
async fn with_dummy_client(f : async (@http.Client) -> Unit) -> Unit {
  @async.with_task_group(root => {
    let server = @x_socket.TcpServer(@x_socket.Addr::parse("127.0.0.1:0"))
    let addr = @x_socket.Addr::parse("127.0.0.1:\{server.addr.port()}")
    root.spawn_bg(no_wait=true, allow_failure=true, () => {
      defer server.close()
      for _ in 0..<2 {
        let accepted = @async.with_timeout_opt(200, () => server.accept())
        match accepted {
          Some((conn, _)) => {
            defer conn.close()
            @async.sleep(80)
          }
          None => break
        }
      }
    })
    let client = @http.Client::new("http://127.0.0.1:\{addr.port()}")
    defer client.close()
    let probe = @x_socket.Tcp::connect(addr)
    probe.close()
    f(client)
  })
}

///|
fn http_chunked_gzip_response(compressed : Bytes) -> Bytes {
  let head = b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Encoding: gzip\r\n\r\n"
  let chunk_head = b"1\r\n"
  let chunk_tail = b"\r\n"
  let tail = b"0\r\n\r\n"
  let mut total = head.length() + tail.length()
  for _ in 0..<compressed.length() {
    total += 6
  }
  Bytes::makei(total, i => {
    let mut cursor = i
    if cursor < head.length() {
      return head[cursor]
    }
    cursor -= head.length()
    for j in 0..<compressed.length() {
      ignore(j)
      if cursor < 3 {
        return chunk_head[cursor]
      }
      cursor -= 3
      if cursor == 0 {
        return compressed[j]
      }
      cursor -= 1
      if cursor < 2 {
        return chunk_tail[cursor]
      }
      cursor -= 2
    }
    tail[cursor]
  })
}

///|
test "parse cookie success" {
  let cookie = @http.Cookie(
    "Cookie2",
    "value2",
    path="/path/to/xxx",
    expires_raw="Sun, 06 Nov 1994 08:49:37 GMT",
    max_age=420000L,
    domain="example.moonbitlang.com",
    secure=true,
    http_only=true,
    extensions=["whatever=whatever"],
  )
  assert_eq(cookie.name, "Cookie2")
  assert_eq(cookie.value, "value2")
  assert_eq(cookie.path.unwrap_or(""), "/path/to/xxx")
  assert_eq(cookie.expires_raw.unwrap_or(""), "Sun, 06 Nov 1994 08:49:37 GMT")
  assert_eq(cookie.max_age.unwrap_or(0L), 420000L)
  assert_eq(cookie.domain.unwrap_or(""), "example.moonbitlang.com")
  assert_true(cookie.secure)
  assert_true(cookie.http_only)
  assert_eq(cookie.extensions[0], "whatever=whatever")
}

///|
test "parse cookie failure" {
  let cookies = @http.Response::{
      code: 200,
      reason: "OK",
      headers: {},
      cookies: [],
    }.cookies
  assert_eq(cookies.length(), 0)
}

///|
async test "read_response passthrough fallback (no length headers)" {
  let (resp, body, _) = raw_get(
    "HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: text/plain\r\n\r\nHello, World!",
  )
  assert_eq(resp.code, 200)
  assert_eq(resp.headers.get("content-type").unwrap_or(""), "text/plain")
  assert_eq(body, "Hello, World!")
}

///|
async test "read_response 204 No Content (no body)" {
  let result = @async.with_timeout_opt(1000, () => {
    raw_get(
      "HTTP/1.1 204 No Content\r\nConnection: keep-alive\r\nDate: Mon, 15 Feb 2026 00:00:00 GMT\r\n\r\n",
      hold_open_ms=2000,
    )
  })
  guard result is Some((resp, body, _)) else { fail("204 response blocked") }
  assert_eq(resp.code, 204)
  assert_eq(body, "")
}

///|
async test "read_response 205 Reset Content (no body)" {
  let result = @async.with_timeout_opt(1000, () => {
    raw_get(
      "HTTP/1.1 205 Reset Content\r\nConnection: keep-alive\r\nDate: Mon, 15 Feb 2026 00:00:00 GMT\r\n\r\n",
      hold_open_ms=2000,
    )
  })
  guard result is Some((resp, body, _)) else { fail("205 response blocked") }
  assert_eq(resp.code, 205)
  assert_eq(body, "")
}

///|
async test "read_response 304 Not Modified (no body)" {
  let result = @async.with_timeout_opt(1000, () => {
    raw_get(
      "HTTP/1.1 304 Not Modified\r\nConnection: keep-alive\r\nETag: \"abc123\"\r\n\r\n",
      hold_open_ms=2000,
    )
  })
  guard result is Some((resp, body, _)) else { fail("304 response blocked") }
  assert_eq(resp.code, 304)
  assert_eq(body, "")
}

///|
async test "read_response informational responses followed by final response" {
  let result = @async.with_timeout_opt(1000, () => {
    raw_get(
      "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 103 Early Hints\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
      hold_open_ms=2000,
    )
  })
  guard result is Some((resp, body, _)) else { fail("100 response blocked") }
  assert_eq(resp.code, 200)
  assert_eq(body, "ok")
}

///|
async test "read_response CONNECT 200 (no body, tunnel mode)" {
  let result = @async.with_timeout_opt(1000, () => {
    raw_request(
      @http.Connect,
      "example.test:443",
      "HTTP/1.1 200 Connection Established\r\n\r\n",
      hold_open_ms=2000,
    )
  })
  guard result is Some((resp, body, request)) else {
    fail("CONNECT response blocked")
  }
  assert_true(request.has_prefix("CONNECT example.test:443 HTTP/1.1"))
  assert_eq(resp.code, 200)
  assert_eq(body, "")
}

///|
async test "read_response HEAD 200 (no body)" {
  let result = @async.with_timeout_opt(1000, () => {
    raw_request(
      @http.Head,
      "/",
      "HTTP/1.1 200 OK\r\nContent-Length: 1234\r\nContent-Type: text/html\r\n\r\n",
      hold_open_ms=2000,
    )
  })
  guard result is Some((resp, body, request)) else {
    fail("HEAD response blocked")
  }
  assert_true(request.has_prefix("HEAD / HTTP/1.1"))
  assert_eq(resp.code, 200)
  assert_eq(resp.headers.get("content-length").unwrap_or(""), "1234")
  assert_eq(body, "")
}

///|
async test "should_read_body_until_close - true cases" {
  for code in [200, 201, 202, 203, 301, 302, 404, 500] {
    let (resp, body, _) = raw_get(
      "HTTP/1.1 \{code} OK\r\nConnection: close\r\n\r\nx",
    )
    assert_eq(resp.code, code)
    assert_eq(body, "x")
  }
}

///|
async test "should_read_body_until_close - false cases (bodyless status codes)" {
  for code in [101, 204, 205, 304] {
    let result = @async.with_timeout_opt(1000, () => {
      raw_get(
        "HTTP/1.1 \{code} OK\r\nConnection: keep-alive\r\n\r\n",
        hold_open_ms=2000,
      )
    })
    guard result is Some((resp, body, _)) else {
      fail("bodyless response blocked")
    }
    assert_eq(resp.code, code)
    assert_eq(body, "")
  }
}

///|
async test "should_read_body_until_close - false cases (headers present)" {
  let (resp1, body1, _) = raw_get(
    "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nx",
  )
  assert_eq(resp1.code, 200)
  assert_eq(body1, "x")
  let (resp2, body2, _) = raw_get(
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1\r\nx\r\n0\r\n\r\n",
  )
  assert_eq(resp2.code, 200)
  assert_eq(body2, "x")
}

///|
async test "should_read_body_until_close - false cases (body already determined)" {
  let (resp1, body1, _) = raw_get(
    "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nx",
  )
  assert_eq(resp1.code, 200)
  assert_eq(body1, "x")
  let (resp2, body2, _) = raw_get(
    "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n1\r\nx\r\n0\r\n\r\n",
  )
  assert_eq(resp2.code, 200)
  assert_eq(body2, "x")
}

///|
async test "should_read_body_until_close - false cases (CONNECT requests)" {
  for code in [200, 201, 299] {
    let result = @async.with_timeout_opt(1000, () => {
      raw_request(
        @http.Connect,
        "example.test:443",
        "HTTP/1.1 \{code} OK\r\nConnection: keep-alive\r\n\r\n",
        hold_open_ms=2000,
      )
    })
    guard result is Some((resp, body, _)) else { fail("CONNECT 2xx blocked") }
    assert_eq(resp.code, code)
    assert_eq(body, "")
  }
  for code in [400, 502] {
    let (resp, _, _) = raw_request(
      @http.Connect,
      "example.test:443",
      "HTTP/1.1 \{code} Error\r\nConnection: close\r\n\r\nx",
    )
    assert_eq(resp.code, code)
  }
}

///|
async test "should_read_body_until_close - false cases (HEAD requests)" {
  for code in [200, 404, 500] {
    let result = @async.with_timeout_opt(1000, () => {
      raw_request(
        @http.Head,
        "/",
        "HTTP/1.1 \{code} OK\r\nConnection: keep-alive\r\n\r\n",
        hold_open_ms=2000,
      )
    })
    guard result is Some((resp, body, _)) else { fail("HEAD response blocked") }
    assert_eq(resp.code, code)
    assert_eq(body, "")
  }
}

///|
async test "gzip split between chunks" {
  let compressed = gzip_bytes("A simple message to compress")
  let response = http_chunked_gzip_response(compressed)
  let (resp, body, _) = raw_get(response)
  assert_eq(resp.code, 200)
  assert_eq(body, "A simple message to compress")
}

///|
async test "read_response parse cookie" {
  let response = "HTTP/1.1 200 OK\r\n" +
    "Set-Cookie: Cookie1=value1\r\n" +
    "Set-Cookie: Cookie2=value2; Path=/path/to/xxx; Max-Age=420000; Secure\r\n" +
    "Set-Cookie: Cookie3=value3; Expires=Sun, 06 Nov 1994 08:49:37 GMT; Domain=example.moonbitlang.com; HttpOnly\r\n" +
    "Set-Cookie: Cookie4=value four; ExtNoArg; ExtWithArg=xxx\r\n" +
    "Content-Length: 0\r\n\r\n"
  let (resp, body, _) = raw_get(response)
  assert_eq(resp.code, 200)
  assert_eq(body, "")
  assert_eq(resp.cookies.length(), 4)
  assert_eq(resp.cookies[0].name, "Cookie1")
  assert_eq(resp.cookies[1].path.unwrap_or(""), "/path/to/xxx")
  assert_eq(resp.cookies[1].max_age.unwrap_or(0L), 420000L)
  assert_true(resp.cookies[1].secure)
  assert_true(resp.cookies[2].http_only)
  assert_eq(resp.cookies[3].extensions.length(), 2)
}

///|
async test "manual Accept-Encoding" {
  let compressed = gzip_bytes("compressed payload")
  let mut plain_body = ""
  let mut gzip_body_len = 0
  @async.with_task_group(root => {
    let server = @x_socket.TcpServer(@x_socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    root.spawn_bg(() => {
      defer server.close()
      for _ in 0..<2 {
        let (conn, _) = server.accept()
        let req = read_http_request(conn)
        if req.to_lower().contains("accept-encoding: gzip") {
          conn.write(
            "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: \{compressed.length()}\r\n\r\n",
          )
          conn.write(compressed)
        } else {
          conn.write(
            "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nplain payload",
          )
        }
        conn.close()
      }
    })
    let (_, plain) = @http.get("http://127.0.0.1:\{port}/")
    plain_body = plain.text()
    let (_, gzip_body) = @http.get("http://127.0.0.1:\{port}/", headers={
      "Accept-Encoding": "gzip",
    })
    gzip_body_len = gzip_body.binary().length()
  })
  assert_eq(plain_body, "compressed payload")
  assert_not_eq(gzip_body_len, "compressed payload".length())
}

///|
async test "request cancel" {
  let start = @env.now()
  let result = try
    @async.with_timeout_opt(120, () => {
      @async.with_task_group(root => {
        let server = @x_socket.TcpServer(@x_socket.Addr::parse("127.0.0.1:0"))
        let port = server.addr.port()
        root.spawn_bg(no_wait=true, allow_failure=true, () => {
          defer server.close()
          let (conn, _) = server.accept()
          defer conn.close()
          ignore(read_http_request(conn))
          @async.sleep(240)
          conn.write(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
        })
        ignore(@http.get("http://127.0.0.1:\{port}/"))
      })
    })
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  let elapsed = (@env.now() - start).to_int()
  match result {
    Ok(None) | Err(_) => ()
    Ok(Some(_)) => fail("request completed before timeout")
  }
  assert_true(elapsed < 220)
}

///|
async test "send fixed length" {
  let mut request = ""
  @async.with_task_group(root => {
    let server = @x_socket.TcpServer(@x_socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    root.spawn_bg(no_wait=true, allow_failure=true, () => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      request = read_http_request(conn)
      conn.write(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
    })
    let client = @http.Client::new("http://127.0.0.1:\{port}")
    defer client.close()
    client.request(@http.Post, "/fixed", extra_headers={ "Content-Length": "3" })
    client.write(b"abc")
    let resp = client.end_request()
    let body = client.read_all().text()
    assert_eq(resp.code, 200)
    assert_eq(body, "ok")
  })
  assert_true(request.has_prefix("POST /fixed HTTP/1.1"))
  assert_true(request.to_lower().contains("content-length: 3"))
  assert_true(request.has_suffix("abc"))
}

///|
async test "send fixed length with flush" {
  let mut request = ""
  @async.with_task_group(root => {
    let server = @x_socket.TcpServer(@x_socket.Addr::parse("127.0.0.1:0"))
    let port = server.addr.port()
    root.spawn_bg(no_wait=true, allow_failure=true, () => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      request = read_http_request(conn)
      conn.write(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
    })
    let client = @http.Client::new("http://127.0.0.1:\{port}")
    defer client.close()
    client.request(@http.Post, "/fixed-flush", extra_headers={
      "Content-Length": "3",
    })
    client.write(b"a")
    client.flush()
    @async.sleep(20)
    client.write(b"bc")
    let resp = client.end_request()
    let body = client.read_all().text()
    assert_eq(resp.code, 200)
    assert_eq(body, "ok")
  })
  assert_true(request.has_prefix("POST /fixed-flush HTTP/1.1"))
  assert_true(request.to_lower().contains("content-length: 3"))
  assert_true(request.has_suffix("abc"))
}

///|
async test "sender write incorrect length" {
  with_dummy_client(client => {
    client.request(@http.Post, "/bad", extra_headers={ "Content-Length": "1" })
    let result = try client.write(b"ab") catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    assert_true(result is Err(_))
  })
}

///|
async test "sender write_reader incorrect length" {
  with_dummy_client(client => {
    client.request(@http.Put, "/bad-reader", extra_headers={
      "Content-Length": "1",
    })
    @async.with_task_group(root => {
      let (r, w) = @io.memory_pipe()
      root.spawn_bg(no_wait=true, allow_failure=true, () => {
        defer w.close()
        w.write(b"ab")
      })
      let result = try client.write_reader(r) catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      assert_true(result is Err(_))
    })
  })
}

///|
async test "sender end_body incorrect length" {
  with_dummy_client(client => {
    client.request(@http.Post, "/short", extra_headers={ "Content-Length": "4" })
    client.write(b"ab")
    let result = try client.end_request() catch {
      err => Err(err)
    } noraise {
      value => Ok(value)
    }
    assert_true(result is Err(_))
  })
}

///|
async test "send_response cookies" {
  @async.with_task_group(root => {
    let server = @http.Server::new(port=0)
    defer server.close()
    root.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        conn.send_response(200, "OK", cookies=[
          @http.Cookie("Cookie1", "value1"),
          @http.Cookie(
            "Cookie2",
            "value2",
            path="/path/to/xxx",
            max_age=420000L,
            secure=true,
          ),
          @http.Cookie(
            "Cookie3",
            "value3",
            expires_raw="Sun, 06 Nov 1994 08:49:37 GMT",
            domain="example.moonbitlang.com",
            http_only=true,
          ),
          @http.Cookie("Cookie4", "value four", extensions=[
            "ExtNoArg", "ExtWithArg=xxx",
          ]),
        ])
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{server.port()}/")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "")
    assert_eq(resp.cookies.length(), 4)
    assert_eq(resp.cookies[3].extensions[1], "ExtWithArg=xxx")
  })
}

///|
async test "send_request empty body" {
  let (resp, body, request) = raw_request(
    @http.Post,
    "/empty",
    "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok",
  )
  assert_eq(resp.code, 200)
  assert_eq(body, "ok")
  assert_true(request.has_prefix("POST /empty HTTP/1.1"))
  assert_eq(content_length_from_headers(request), 0)
  let header_end = request.find("\r\n\r\n").unwrap() + 4
  assert_eq(request[header_end:], "")
}

///|
async test "send_response empty body" {
  for code in [200, 204, 205, 304] {
    let result = @async.with_timeout_opt(500, () => {
      let mut response = None
      @async.with_task_group(root => {
        let server = @http.Server::new(port=0)
        defer server.close()
        root.spawn_bg(no_wait=true, allow_failure=true, () => {
          server.run_forever((_req, _body, conn) => {
            conn.send_response(code, "OK")
            conn.end_response()
          })
        })
        @async.sleep(20)
        response = Some(@http.get("http://127.0.0.1:\{server.port()}/"))
      })
      response.unwrap()
    })
    guard result is Some((resp, body)) else { fail("empty response blocked") }
    assert_eq(resp.code, code)
    assert_eq(body.text(), "")
  }
}
