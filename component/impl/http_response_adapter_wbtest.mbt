///|
test "component impl: http response adapter helpers convert response bytes" {
  let headers = wasmhttp_pairs_to_headers([
    ("content-type", "application/x-test"),
    ("x-test", "ok"),
  ])
  assert_eq(headers.get("content-type"), Some("application/x-test"))
  assert_eq(headers.get("x-test"), Some("ok"))

  let wit_response : @wit_http.HttpResponse = {
    code: 201,
    headers: [("content-type", "application/x-test"), ("x-test", "ok")],
  }
  let (response, response_body) = wasmhttp_unwrap_result(
    Ok((wit_response, [4, 5])),
  )
  assert_eq(response.code, 201)
  assert_eq(response.headers.get("content-type"), Some("application/x-test"))
  assert_eq(response.headers.get("x-test"), Some("ok"))
  assert_eq(response_body.to_array(), [4, 5])
}

///|
test "component impl: http response adapter helpers map Err to IoError" {
  let response_result : Result[(@bit.HttpResponse, Bytes), @bit.GitError] = try? wasmhttp_unwrap_result(
    Err("boom-http"),
  )
  match response_result {
    Err(@bit.GitError::IoError(msg)) => assert_eq(msg, "boom-http")
    _ => assert_true(false)
  }
}
