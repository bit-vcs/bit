///|
// Keep the public String-keyed API while upstream compares HTTP names ignoring case.
fn to_upstream_headers(
  headers : Map[String, String],
) -> Map[@async_http.CaseInsensitiveString, String] {
  let result : Map[@async_http.CaseInsensitiveString, String] = Map([])
  for name, value in headers {
    result[@async_http.CaseInsensitiveString(name)] = value
  }
  result
}

///|
pub struct Conn {
  inner : @async_ws.Conn
}

///|
fn to_upstream_request_method(
  meth : @http.RequestMethod,
) -> @async_http.RequestMethod {
  match meth {
    @http.RequestMethod::Get => @async_http.RequestMethod::Get
    @http.RequestMethod::Head => @async_http.RequestMethod::Head
    @http.RequestMethod::Post => @async_http.RequestMethod::Post
    @http.RequestMethod::Put => @async_http.RequestMethod::Put
    @http.RequestMethod::Delete => @async_http.RequestMethod::Delete
    @http.RequestMethod::Connect => @async_http.RequestMethod::Connect
    @http.RequestMethod::Options => @async_http.RequestMethod::Options
    @http.RequestMethod::Trace => @async_http.RequestMethod::Trace
    @http.RequestMethod::Patch => @async_http.RequestMethod::Patch
  }
}

///|
fn to_upstream_request(request : @http.Request) -> @async_http.RequestHeader {
  {
    meth: to_upstream_request_method(request.meth),
    path: request.path,
    headers: to_upstream_headers(request.headers),
  }
}

///|
fn from_upstream_close_code(code : @async_ws.CloseCode) -> CloseCode {
  match code {
    @async_ws.Normal => Normal
    @async_ws.GoingAway => GoingAway
    @async_ws.CloseCode::ProtocolError => CloseCode::ProtocolError
    @async_ws.UnsupportedData => UnsupportedData
    @async_ws.Abnormal => Abnormal
    @async_ws.InvalidFramePayload => InvalidFramePayload
    @async_ws.PolicyViolation => PolicyViolation
    @async_ws.MessageTooBig => MessageTooBig
    @async_ws.MissingExtension => MissingExtension
    @async_ws.InternalError => InternalError
    @async_ws.Other(n) => Other(n)
  }
}

///|
fn to_upstream_close_code(code : CloseCode) -> @async_ws.CloseCode {
  match code {
    Normal => @async_ws.Normal
    GoingAway => @async_ws.GoingAway
    CloseCode::ProtocolError => @async_ws.CloseCode::ProtocolError
    UnsupportedData => @async_ws.UnsupportedData
    Abnormal => @async_ws.Abnormal
    InvalidFramePayload => @async_ws.InvalidFramePayload
    PolicyViolation => @async_ws.PolicyViolation
    MessageTooBig => @async_ws.MessageTooBig
    MissingExtension => @async_ws.MissingExtension
    InternalError => @async_ws.InternalError
    Other(n) => @async_ws.Other(n)
  }
}

///|
pub async fn from_http_server(
  request : @http.Request,
  conn : @http.ServerConnection,
) -> Conn raise WebSocketError {
  let inner = @async_ws.from_http_server(
    to_upstream_request(request),
    conn.inner,
  ) catch {
    err => raise WebSocketError::InvalidHandshake(err.to_string())
  }
  Conn::{ inner, }
}

///|
pub async fn Conn::connect(
  url : String,
  headers? : Map[String, String],
) -> Conn raise WebSocketError {
  let inner = @async_ws.Conn::connect(
    url,
    headers?=headers.map(to_upstream_headers),
  ) catch {
    err => raise WebSocketError::InvalidHandshake(err.to_string())
  }
  Conn::{ inner, }
}

///|
pub async fn Conn::recv(self : Conn) -> Message raise WebSocketError {
  let msg = self.inner.recv() catch {
    @async_ws.ConnectionClosed(code, reason) =>
      raise WebSocketError::ConnectionClosed(
        from_upstream_close_code(code),
        reason,
      )
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
  let data : &@data.Data = @io.BinaryReader::read_all(msg) catch {
    err => raise WebSocketError::ProtocolError((err : Error).to_string())
  }
  match msg.kind {
    @async_ws.Text => Message::Text(data.text() catch { _ => "" })
    @async_ws.Binary => Message::Binary(data.binary())
  }
}

///|
pub async fn Conn::send_text(
  self : Conn,
  text : StringView,
) -> Unit raise WebSocketError {
  self.inner.send_text(text) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub async fn Conn::send_binary(
  self : Conn,
  data : BytesView,
) -> Unit raise WebSocketError {
  self.inner.send_binary(data) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub async fn Conn::send_close(
  self : Conn,
  code? : CloseCode,
  reason? : String,
) -> Unit raise WebSocketError {
  self.inner.send_close(code?=code.map(to_upstream_close_code), reason?) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}

///|
pub fn Conn::close(self : Conn) -> Unit {
  self.inner.close()
}

///|
pub async fn Conn::ping(
  self : Conn,
  msg? : BytesView,
) -> Unit raise WebSocketError {
  self.inner.ping(msg?) catch {
    err => raise WebSocketError::ProtocolError(err.to_string())
  }
}
