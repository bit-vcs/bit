///|
pub(all) struct Conn {}

///|
async fn[T] unsupported() -> T raise WebSocketError {
  @async.pause() catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
  keep_websocket_error_constructors_used()
  raise WebSocketError::ProtocolError(
    "WebSocket is not supported on wasm target",
  )
}

///|
pub async fn Conn::connect(
  _url : String,
  headers? : Map[String, String],
) -> Conn raise WebSocketError {
  ignore(headers)
  unsupported()
}

///|
pub async fn Conn::recv(_self : Conn) -> Message raise WebSocketError {
  unsupported()
}

///|
pub async fn Conn::send_text(
  _self : Conn,
  _text : StringView,
) -> Unit raise WebSocketError {
  unsupported()
}

///|
pub async fn Conn::send_binary(
  _self : Conn,
  _data : BytesView,
) -> Unit raise WebSocketError {
  unsupported()
}

///|
pub async fn Conn::send_close(
  _self : Conn,
  code? : CloseCode,
  reason? : String,
) -> Unit raise WebSocketError {
  ignore(code)
  ignore(reason)
  unsupported()
}

///|
pub fn Conn::close(_self : Conn) -> Unit {
  keep_websocket_error_constructors_used()
  abort("WebSocket is not supported on wasm target")
}

///|
pub async fn Conn::ping(
  _self : Conn,
  msg? : BytesView,
) -> Unit raise WebSocketError {
  ignore(msg)
  unsupported()
}
