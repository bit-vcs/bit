// Microbenchmarks for the sync surface of mizchi/x/websocket.
//
// The high-level `Conn::*` operations are async (they bridge to Node's
// WebSocket via FFI or to moonbitlang/core/async/websocket on native), so
// `@bench.T` can only reach the sync helpers: the `CloseCode` <-> int
// conversion that runs on every close handshake, plus the `Message`
// constructor used to wrap inbound frames.

///|
let close_code_cases : Array[Int32] = [
  1000, 1001, 1002, 1003, 1006, 1007, 1008, 1009, 1010, 1011,
  // A custom code that falls through to `Other(_)`.
   4321,
]

///|
let close_code_values : Array[CloseCode] = [
  Normal,
  GoingAway,
  ProtocolError,
  UnsupportedData,
  Abnormal,
  InvalidFramePayload,
  PolicyViolation,
  MessageTooBig,
  MissingExtension,
  InternalError,
  Other(4321),
]

///|
let bench_text : String = "hello websocket bench"

///|
let bench_payload : Bytes = b"hello websocket binary payload"

///|
test "bench websocket close_code_from_int matrix" (b : @bench.T) {
  b.bench(() => {
    for code in close_code_cases {
      b.keep(close_code_from_int(code))
    }
  })
}

///|
test "bench websocket close_code_to_int matrix" (b : @bench.T) {
  b.bench(() => {
    for cc in close_code_values {
      b.keep(close_code_to_int(cc))
    }
  })
}

///|
test "bench websocket Message::Text construct" (b : @bench.T) {
  b.bench(() => b.keep(Message::Text(bench_text)))
}

///|
test "bench websocket Message::Binary construct" (b : @bench.T) {
  b.bench(() => b.keep(Message::Binary(bench_payload)))
}
