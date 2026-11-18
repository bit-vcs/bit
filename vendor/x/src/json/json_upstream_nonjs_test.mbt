// Non-JS ports from `moonbitlang/core/json`.
//
// These assert an exact source position for an error that occurs where a JSON
// *value* is expected (a stray token, or a form-feed control char inside an
// array). On native and wasm/wasm-gc the error comes from the pure-MoonBit
// parser (native delegates to it; wasm falls back to it when the simdjson fast
// path bails), so the exact `{ line, column }` is reported. The JS host
// `JSON.parse` phrases such failures as "Unexpected token X ... is not valid
// JSON" with no position, so it cannot recover the exact position there; the
// variant-level behavior stays covered cross-target in
// `json_upstream_test.mbt`.

///|
test "parse multi-lines json error" {
  let result = try_parse(
    (
      #|{
      #|  "a":2,
      #|  "b":a
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|Err(InvalidChar({ line: 3, column: 6 }, 'a'))
    ),
  )
}

///|
test "parse error" {
  debug_inspect(
    try_parse("[1, 2, ]"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 7 }, '\u{0c}'))
    ),
  )
}

///|
test "parse whitespace error" {
  debug_inspect(
    try_parse("[1, 2,3   ,4  ]"),
    content=(
      #|Err(InvalidChar({ line: 1, column: 9 }, '\u{0c}'))
    ),
  )
}
