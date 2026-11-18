///|
test "extract_host_url - http with path" {
  assert_eq(
    extract_host_url("http://www.example.org/path/to"),
    "http://www.example.org",
  )
}

///|
test "extract_host_url - http without path" {
  assert_eq(
    extract_host_url("http://www.example.org"),
    "http://www.example.org",
  )
}

///|
test "extract_host_url - https with path and query" {
  assert_eq(
    extract_host_url("https://www.example.org/path/to?search=q"),
    "https://www.example.org",
  )
}

///|
test "extract_host_url - with port" {
  assert_eq(
    extract_host_url("http://www.example.org:10042/path"),
    "http://www.example.org:10042",
  )
}

///|
test "extract_host_url - with port no path" {
  assert_eq(
    extract_host_url("http://www.example.org:10042"),
    "http://www.example.org:10042",
  )
}

///|
test "extract_path_from_url - with path" {
  assert_eq(extract_path_from_url("http://www.example.org/path/to"), "/path/to")
}

///|
test "extract_path_from_url - no path" {
  assert_eq(extract_path_from_url("http://www.example.org"), "/")
}

///|
test "extract_path_from_url - root path" {
  assert_eq(extract_path_from_url("http://www.example.org/"), "/")
}

///|
test "extract_path_from_url - with query" {
  assert_eq(
    extract_path_from_url("https://www.example.org/path/to?search=q"),
    "/path/to?search=q",
  )
}

///|
test "extract_path_from_url - with port" {
  assert_eq(extract_path_from_url("http://www.example.org:10042/path"), "/path")
}

///|
test "upstream headers use case insensitive keys without mutating input" {
  let headers : Map[String, String] = { "X-ReQuEsT-Id": "request-123" }
  let upstream = to_upstream_headers(headers)
  assert_eq(upstream.get("x-request-id"), Some("request-123"))
  assert_eq(upstream.get("X-REQUEST-ID"), Some("request-123"))
  assert_eq(headers.get("X-ReQuEsT-Id"), Some("request-123"))
  assert_eq(headers.get("x-request-id"), None)
}

///|
test "extract_path_from_url - with port no path" {
  assert_eq(extract_path_from_url("http://www.example.org:10042"), "/")
}
