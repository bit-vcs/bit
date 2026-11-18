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
fn extract_host_url(url : String) -> String {
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    url
  } else {
    url[:path_start].to_owned()
  }
}

///|
fn extract_path_from_url(url : String) -> String {
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    "/"
  } else {
    url[path_start:].to_owned()
  }
}

///|
fn to_response(resp : @async_http.ResponseHeader) -> Response {
  let headers : Map[String, String] = Map([])
  for k, v in resp.headers {
    headers[k.to_string().to_lower()] = v
  }
  let cookies = resp.cookies.map(to_cookie)
  Response::{ code: resp.code, reason: resp.reason, headers, cookies, }
}

///|
fn to_cookie(cookie : @async_http.Cookie) -> Cookie {
  Cookie(
    cookie.name,
    cookie.value,
    path?=cookie.path,
    expires_raw?=cookie.expires_raw,
    max_age?=cookie.max_age,
    domain?=cookie.domain,
    secure=cookie.secure,
    http_only=cookie.http_only,
    extensions=cookie.extensions,
  )
}

///|
fn from_cookie(cookie : Cookie) -> @async_http.Cookie {
  @async_http.Cookie(
    cookie.name,
    cookie.value,
    path?=cookie.path,
    expires_raw?=cookie.expires_raw,
    max_age?=cookie.max_age,
    domain?=cookie.domain,
    secure=cookie.secure,
    http_only=cookie.http_only,
    extensions=cookie.extensions,
  )
}

///|
fn from_request_method(meth : RequestMethod) -> @async_http.RequestMethod {
  match meth {
    Get => @async_http.RequestMethod::Get
    Head => @async_http.RequestMethod::Head
    Post => @async_http.RequestMethod::Post
    Put => @async_http.RequestMethod::Put
    Delete => @async_http.RequestMethod::Delete
    Connect => @async_http.RequestMethod::Connect
    Options => @async_http.RequestMethod::Options
    Trace => @async_http.RequestMethod::Trace
    Patch => @async_http.RequestMethod::Patch
  }
}

///|
pub struct Client {
  priv write_controller : @io.BinaryWriterController
  priv mut read_controller : @io.BinaryReaderController
  inner : @async_http.ClientConnection
  priv mut request_method : RequestMethod?
  priv mut response_has_no_body : Bool
}

///|
pub async fn Client::new(
  url : String,
  headers? : Map[String, String],
  proxy? : Client,
  verify~ : Bool = true,
  trust? : @tls.TrustedRoot,
) -> Client raise HttpError {
  let proxy = proxy.map(fn(proxy) { proxy.inner })
  let trust = match trust {
    Some(trust) => trust
    None => if verify { @tls.SystemRoot } else { @tls.NoVerification }
  }
  let client = @async_http.ClientConnection(
    url,
    headers=to_upstream_headers(headers.unwrap_or({})),
    proxy?,
    trust~,
  ) catch {
    _ => raise HttpError::InvalidUrl(url)
  }
  Client::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    inner: client,
    request_method: None,
    response_has_no_body: false,
  }
}

///|
pub fn Client::close(self : Client) -> Unit {
  self.inner.close()
}

///|
pub async fn Client::request(
  self : Client,
  meth : RequestMethod,
  path : StringView,
  extra_headers? : Map[String, String],
) -> Unit raise HttpError {
  self.read_controller = @io.BinaryReaderController()
  self.request_method = Some(meth)
  self.response_has_no_body = false
  self.inner.request(
    from_request_method(meth),
    path,
    extra_headers=to_upstream_headers(extra_headers.unwrap_or({})),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::end_request(self : Client) -> Response raise HttpError {
  let meth = self.request_method
  let response = self.inner.end_request() catch {
    err => raise classify_http_error(err.to_string())
  }
  let resp = to_response(response)
  self.response_has_no_body = response_has_no_body(resp.code, meth)
  self.request_method = None
  resp
}

///|
pub async fn Client::flush(self : Client) -> Unit raise HttpError {
  self.inner.flush_partial_data() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::skip_response_body(self : Client) -> Unit raise HttpError {
  self.read_controller = @io.BinaryReaderController()
  self.inner.skip_response_body() catch {
    err => raise classify_http_error(err.to_string())
  }
  self.response_has_no_body = false
}

///|
pub async fn Client::enter_passthrough_mode(
  self : Client,
) -> Unit raise HttpError {
  self.read_controller = @io.BinaryReaderController()
  self.response_has_no_body = false
  self.inner.enter_passthrough_mode() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn Client::get(
  self : Client,
  path : String,
  extra_headers? : Map[String, String],
  body? : &@data.Data,
) -> Response raise HttpError {
  self.request(Get, path, extra_headers=extra_headers.unwrap_or({}))
  ignore(
    self.write(body.unwrap_or("").binary()[:]) catch {
      err => raise classify_http_error(err.to_string())
    },
  )
  self.end_request()
}

///|
pub async fn Client::post(
  self : Client,
  path : String,
  body : &@data.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  self.request(Post, path, extra_headers?)
  self.write(body.binary()[:]) catch {
    err => raise classify_http_error(err.to_string())
  }
  self.end_request()
}

///|
pub async fn Client::put(
  self : Client,
  path : String,
  body : &@data.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  self.request(Put, path, extra_headers?)
  self.write(body.binary()[:]) catch {
    err => raise classify_http_error(err.to_string())
  }
  self.end_request()
}

///|
impl @io.BinaryReaderImpl for Client with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for Client with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  if self.response_has_no_body {
    0
  } else {
    self.inner.read_into(buf, offset~, max_len~)
  }
}

///|
impl @io.BinaryWriterImpl for Client with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
async fn request_internal(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@data.Data,
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  let upstream_proxy = proxy.map(fn(proxy) { proxy.inner })
  let (resp, body_data) = try {
    match meth {
      "POST" => {
        let (resp, body_data) = @async_http.post_binary(
          url,
          body.binary()[:],
          headers=to_upstream_headers(headers),
          proxy?=upstream_proxy,
        )
        (to_response(resp), body_data.binary())
      }
      "PUT" => {
        let (resp, body_data) = @async_http.put_binary(
          url,
          body.binary()[:],
          headers=to_upstream_headers(headers),
          proxy?=upstream_proxy,
        )
        (to_response(resp), body_data.binary())
      }
      _ => {
        let client = Client::new(extract_host_url(url), proxy?)
        defer client.close()
        let resp = client.get(
          extract_path_from_url(url),
          extra_headers=headers,
          body~,
        )
        (resp, client.read_all().binary())
      }
    }
  } catch {
    err => raise classify_http_error(err.to_string())
  }
  (resp, body_data)
}

///|
async fn create_stream_client(
  url : String,
  meth : RequestMethod,
  headers : Map[String, String],
  body : &@data.Data,
  proxy? : Client,
) -> (Response, Client) raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = Client::new(host_url, proxy?)
  let resp = try {
    match meth {
      Get => {
        client.request(Get, path, extra_headers=headers)
        ignore(
          client.write(body.binary()[:]) catch {
            err => raise classify_http_error(err.to_string())
          },
        )
        client.end_request()
      }
      _ => {
        client.request(meth, path, extra_headers=headers)
        ignore(
          client.write(body.binary()[:]) catch {
            err => raise classify_http_error(err.to_string())
          },
        )
        client.end_request()
      }
    }
  } catch {
    err => {
      client.close()
      raise classify_http_error(err.to_string())
    }
  }
  (resp, client)
}

// Streaming API

///|
pub struct Stream {
  inner : @async_http.ClientConnection
}

///|
async fn stream_request_internal(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@data.Data,
) -> (Response, Stream) raise HttpError {
  let (resp, client) = create_stream_client(
    url,
    if meth == "POST" {
      Post
    } else if meth == "PUT" {
      Put
    } else {
      Get
    },
    headers,
    body,
  )
  (resp, Stream::{ inner: client.inner, })
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
  body~ : &@data.Data = "",
  proxy? : Client,
) -> (Response, Client) raise HttpError {
  create_stream_client(url, Get, headers.unwrap_or({}), body, proxy?)
}

///|
pub async fn post_stream(
  url : String,
  headers? : Map[String, String],
  proxy? : Client,
) -> Client raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = Client::new(host_url, proxy?)
  try client.request(Post, path, extra_headers=headers.unwrap_or({})) catch {
    err => {
      client.close()
      raise classify_http_error(err.to_string())
    }
  } noraise {
    _ => client
  }
}

///|
pub async fn put_stream(
  url : String,
  headers? : Map[String, String],
  proxy? : Client,
) -> Client raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = Client::new(host_url, proxy?)
  try client.request(Put, path, extra_headers=headers.unwrap_or({})) catch {
    err => {
      client.close()
      raise classify_http_error(err.to_string())
    }
  } noraise {
    _ => client
  }
}

///|
pub async fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  self.inner.read() catch {
    err => raise classify_http_error(error_message(err))
  }
}

///|
pub async fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  let data : &@data.Data = @io.BinaryReader::read_all(self.inner) catch {
    err => raise classify_http_error(error_message(err))
  }
  data.binary()
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  self.inner.close()
}

// Non-streaming API

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
  body~ : &@data.Data = "",
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  request_internal(url, "GET", headers.unwrap_or({}), body, proxy?)
}

///|
pub async fn post(
  url : String,
  body : &@data.Data,
  headers? : Map[String, String],
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  request_internal(url, "POST", headers.unwrap_or({}), body, proxy?)
}

///|
pub async fn put(
  url : String,
  body : &@data.Data,
  headers? : Map[String, String],
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  request_internal(url, "PUT", headers.unwrap_or({}), body, proxy?)
}

// Server API

///|
pub struct Server {
  inner : @async_http.Server
}

///|
pub struct ServerConnection {
  priv write_controller : @io.BinaryWriterController
  priv mut read_controller : @io.BinaryReaderController
  inner : @async_http.ServerConnection
}

///|
fn to_request_method(
  meth : @async_http.RequestMethod,
) -> RequestMethod raise HttpError {
  match meth {
    Get => RequestMethod::Get
    Head => RequestMethod::Head
    Post => RequestMethod::Post
    Put => RequestMethod::Put
    Delete => RequestMethod::Delete
    Connect => RequestMethod::Connect
    Options => RequestMethod::Options
    Trace => RequestMethod::Trace
    Patch => RequestMethod::Patch
    _ => raise HttpError::NotSupported
  }
}

///|
fn to_request(req : @async_http.RequestHeader) -> Request raise HttpError {
  let headers : Map[String, String] = Map([])
  for k, v in req.headers {
    headers[k.to_string().to_lower()] = v
  }
  Request::{ meth: to_request_method(req.meth), path: req.path, headers, }
}

///|
fn to_addr(addr : @socket.Addr) -> Addr {
  Addr::{ text: addr.to_string(), port: addr.port.to_int(), }
}

///|
pub async fn Server::new(
  host? : String,
  port? : Int32,
  headers? : Map[String, String],
  dual_stack? : Bool,
  reuse_addr? : Bool,
  max_request_body_bytes? : Int32,
  request_timeout_ms? : Int32,
  keep_alive_timeout_ms? : Int32,
  headers_timeout_ms? : Int32,
  accept_queue_limit? : Int32,
  trust_proxy? : Bool,
) -> Server raise HttpError {
  ignore(max_request_body_bytes)
  ignore(request_timeout_ms)
  ignore(keep_alive_timeout_ms)
  ignore(headers_timeout_ms)
  ignore(accept_queue_limit)
  ignore(trust_proxy)
  let h = host.unwrap_or("127.0.0.1")
  let p = port.unwrap_or(3000)
  let addr = @socket.Addr::parse("\{h}:\{p}") catch {
    _ => raise HttpError::InvalidUrl("\{h}:\{p}")
  }
  let server = @async_http.Server(
    addr,
    dual_stack?,
    reuse_addr?,
    headers=to_upstream_headers(headers.unwrap_or({})),
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
  Server::{ inner: server, }
}

///|
pub fn Server::port(self : Server) -> Int32 {
  self.inner.addr.port.to_int()
}

///|
pub fn Server::addr(self : Server) -> Addr {
  to_addr(self.inner.addr)
}

///|
pub fn Server::close(self : Server) -> Unit {
  self.inner.close()
}

///|
pub async fn Server::close_graceful(
  self : Server,
  timeout_ms? : Int32,
) -> Unit raise HttpError {
  let timeout = timeout_ms.unwrap_or(30000)
  if timeout < 0 {
    raise HttpError::NetworkError("timeout_ms must be >= 0")
  }
  @async.sleep(0)
  self.close()
}

///|
pub async fn Server::accept(
  self : Server,
) -> (ServerConnection, Addr) raise HttpError {
  let (conn, addr) = self.inner.accept() catch {
    err => raise classify_http_error(err.to_string())
  }
  (
    ServerConnection::{
      write_controller: @io.BinaryWriterController(),
      read_controller: @io.BinaryReaderController(),
      inner: conn,
    },
    to_addr(addr),
  )
}

///|
pub async fn Server::run_forever(
  self : Server,
  f : async (Request, &@io.BinaryReader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit raise HttpError {
  self.inner.run_forever(
    (req, conn) => {
      let wrapped = ServerConnection::{
        write_controller: @io.BinaryWriterController(),
        read_controller: @io.BinaryReaderController(),
        inner: conn,
      }
      f(to_request(req), wrapped, wrapped)
    },
    allow_failure?,
    max_connections?,
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  self.inner.close()
}

///|
pub fn ServerConnection::client_addr(self : ServerConnection) -> Addr {
  to_addr(self.inner.client_addr())
}

///|
pub async fn ServerConnection::read_request(
  self : ServerConnection,
) -> Request raise HttpError {
  self.read_controller = @io.BinaryReaderController()
  let req = self.inner.read_request() catch {
    err => raise classify_http_error(err.to_string())
  }
  to_request(req)
}

///|
pub async fn ServerConnection::skip_request_body(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.read_controller = @io.BinaryReaderController()
  self.inner.skip_request_body() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::send_response(
  self : ServerConnection,
  code : Int32,
  reason : String,
  extra_headers? : Map[String, String],
  cookies~ : Array[Cookie] = [],
) -> Unit raise HttpError {
  let cookies = cookies.map(from_cookie)
  self.inner.send_response(
    code,
    reason,
    extra_headers=to_upstream_headers(extra_headers.unwrap_or({})),
    cookies~,
  ) catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::flush(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.inner.flush_partial_data() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::end_response(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.inner.end_response() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
pub async fn ServerConnection::enter_passthrough_mode(
  self : ServerConnection,
) -> Unit raise HttpError {
  self.read_controller = @io.BinaryReaderController()
  self.inner.enter_passthrough_mode() catch {
    err => raise classify_http_error(err.to_string())
  }
}

///|
impl @io.BinaryReaderImpl for ServerConnection with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for ServerConnection with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub impl @io.BinaryReader for Client

///|
pub extend Client with @io.BinaryReader::{
  read_into,
  read_at_least,
  peek,
  peek_at_least,
  read_exactly,
  drop_exactly,
  peek_exactly,
  drop_all,
  peek_until,
}

///|
pub impl @io.BinaryReader for ServerConnection

///|
pub extend ServerConnection with @io.BinaryReader::{
  read_into,
  read_at_least,
  peek,
  peek_at_least,
  read_exactly,
  drop_exactly,
  peek_exactly,
  drop_all,
  peek_until,
}

///|
pub impl @io.BinaryWriter for Client

///|
pub extend Client with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for Client with fn get_controller(self) {
  self.write_controller
}

///|
pub impl @io.BinaryWriter for ServerConnection

///|
pub extend ServerConnection with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn get_controller(self) {
  self.write_controller
}

///|
impl @io.BinaryReaderImpl for Client with fn name(_self) {
  "Client"
}

///|
impl @io.BinaryReaderImpl for ServerConnection with fn name(_self) {
  "ServerConnection"
}

///|
impl @io.BinaryWriterImpl for Client with fn name(_self) {
  "Client"
}

///|
impl @io.BinaryWriterImpl for Client with fn flush_partial_data(self) {
  self.flush()
}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn name(_self) {
  "ServerConnection"
}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn flush_partial_data(self) {
  self.flush()
}

///|
/// Core's reader/writer errors only derive `Debug`; `Error` still has `Show`.
fn error_message(err : Error) -> String {
  err.to_string()
}
