///|
let bench_headers : Map[String, String] = {
  "Content-Type": "application/json",
  "Content-Length": "1024",
  "Cache-Control": "no-cache",
  "Accept-Encoding": "gzip,identity",
  "X-Request-Id": "0123456789abcdef",
  "X-Trace-Id": "abcdef0123456789",
  "Server": "mizchi-x",
  "Date": "Tue, 12 May 2026 00:00:00 GMT",
}

///|
let bench_headers_json : String = headers_to_json(bench_headers)

///|
let bench_lower_headers : Map[String, String] = {
  "content-type": "application/json",
  "content-length": "1024",
  "cache-control": "no-cache",
  "accept-encoding": "gzip,identity",
  "x-request-id": "0123456789abcdef",
  "x-trace-id": "abcdef0123456789",
  "server": "mizchi-x",
  "date": "Tue, 12 May 2026 00:00:00 GMT",
}

///|
let bench_lower_headers_json : String = headers_to_json(bench_lower_headers)

///|
let bench_cookies : Array[Cookie] = [
  Cookie("sid", "0123456789abcdef", path="/", http_only=true, secure=true),
  Cookie("theme", "dark", path="/"),
  Cookie("locale", "ja-JP", max_age=86400L),
  Cookie("feature", "http-bench", extensions=["SameSite=Lax"]),
]

///|
let bench_cookies_json : String = cookies_to_json(bench_cookies)

///|
test "bench http headers_to_json" (b : @bench.T) {
  b.bench(fn() { b.keep(headers_to_json(bench_headers)) })
}

///|
test "bench http parse_headers_json mixed-case input" (b : @bench.T) {
  b.bench(fn() { b.keep(parse_headers_json(bench_headers_json)) })
}

///|
test "bench http parse_headers_json lower-case input" (b : @bench.T) {
  b.bench(fn() { b.keep(parse_headers_json(bench_lower_headers_json)) })
}

///|
test "bench http cookies_to_json" (b : @bench.T) {
  b.bench(fn() { b.keep(cookies_to_json(bench_cookies)) })
}

///|
test "bench http parse_cookies_json" (b : @bench.T) {
  b.bench(fn() { b.keep(parse_cookies_json(bench_cookies_json)) })
}

///|
test "bench http response_has_no_body matrix" (b : @bench.T) {
  b.bench(fn() {
    let mut count = 0
    for code in [100, 101, 199, 200, 204, 205, 304, 400, 500] {
      if response_has_no_body(code, Some(Get)) {
        count += 1
      }
      if response_has_no_body(code, Some(Head)) {
        count += 1
      }
      if response_has_no_body(code, Some(Connect)) {
        count += 1
      }
    }
    b.keep(count)
  })
}
