///|
pub struct Stream {}

///|
pub fn get_stream(
  _url : String,
  headers? : Map[String, String],
  body~ : &@data.Data = "",
  proxy? : Client,
) -> (Response, Client) raise HttpError {
  ignore(headers)
  ignore(body)
  ignore(proxy)
  raise HttpError::NotSupported
}

///|
pub fn post_stream(
  _url : String,
  headers? : Map[String, String],
  proxy? : Client,
) -> Client raise HttpError {
  ignore(headers)
  ignore(proxy)
  raise HttpError::NotSupported
}

///|
pub fn put_stream(
  _url : String,
  headers? : Map[String, String],
  proxy? : Client,
) -> Client raise HttpError {
  ignore(headers)
  ignore(proxy)
  raise HttpError::NotSupported
}

///|
pub fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  ignore(self)
  abort("Stream::close not supported on wasm target")
}

///|
pub fn get(
  _url : String,
  headers? : Map[String, String],
  body~ : &@data.Data = "",
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  ignore(headers)
  ignore(body)
  ignore(proxy)
  raise HttpError::NotSupported
}

///|
pub fn post(
  _url : String,
  _body : &@data.Data,
  headers? : Map[String, String],
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  ignore(headers)
  ignore(proxy)
  raise HttpError::NotSupported
}

///|
pub fn put(
  _url : String,
  _body : &@data.Data,
  headers? : Map[String, String],
  proxy? : Client,
) -> (Response, &@data.Data) raise HttpError {
  ignore(headers)
  ignore(proxy)
  raise HttpError::NotSupported
}

// Native-compatible Client API

///|
pub struct Client {}

///|
pub fn Client::new(
  url : String,
  headers? : Map[String, String],
  proxy? : Client,
  verify~ : Bool = true,
) -> Client raise HttpError {
  ignore(url)
  ignore(headers)
  ignore(proxy)
  ignore(verify)
  raise HttpError::NotSupported
}

///|
pub fn Client::close(self : Client) -> Unit {
  ignore(self)
}

///|
pub fn Client::request(
  self : Client,
  meth : RequestMethod,
  path : StringView,
  extra_headers? : Map[String, String],
) -> Unit raise HttpError {
  ignore(self)
  ignore(meth)
  ignore(path)
  ignore(extra_headers)
  raise HttpError::NotSupported
}

///|
pub fn Client::end_request(self : Client) -> Response raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Client::flush(self : Client) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Client::skip_response_body(self : Client) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Client::enter_passthrough_mode(self : Client) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Client::get(
  self : Client,
  path : String,
  extra_headers? : Map[String, String],
  body? : &@data.Data,
) -> Response raise HttpError {
  ignore(self)
  ignore(path)
  ignore(extra_headers)
  ignore(body)
  raise HttpError::NotSupported
}

///|
pub fn Client::post(
  self : Client,
  path : String,
  body : &@data.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  ignore(self)
  ignore(path)
  ignore(body)
  ignore(extra_headers)
  raise HttpError::NotSupported
}

///|
pub fn Client::put(
  self : Client,
  path : String,
  body : &@data.Data,
  extra_headers? : Map[String, String],
) -> Response raise HttpError {
  ignore(self)
  ignore(path)
  ignore(body)
  ignore(extra_headers)
  raise HttpError::NotSupported
}

///|
impl @io.BinaryReaderImpl for Client with fn get_controller(self) {
  ignore(self)
  abort("Client reader not supported on wasm target")
}

///|
impl @io.BinaryReaderImpl for Client with fn raw_read_impl(
  self,
  _buf,
  offset~,
  max_len~,
) {
  ignore(self)
  ignore(offset)
  ignore(max_len)
  raise HttpError::NotSupported
}

///|
impl @io.BinaryWriterImpl for Client with fn raw_write_impl(
  self,
  _buf,
  offset~,
  len~,
) {
  ignore(self)
  ignore(offset)
  ignore(len)
  raise HttpError::NotSupported
}

// Server API

///|
pub struct Server {}

///|
pub struct ServerConnection {}

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
  ignore(host)
  ignore(port)
  ignore(headers)
  ignore(dual_stack)
  ignore(reuse_addr)
  ignore(max_request_body_bytes)
  ignore(request_timeout_ms)
  ignore(keep_alive_timeout_ms)
  ignore(headers_timeout_ms)
  ignore(accept_queue_limit)
  ignore(trust_proxy)
  raise HttpError::NotSupported
}

///|
pub fn Server::port(self : Server) -> Int32 {
  ignore(self)
  0
}

///|
pub fn Server::addr(self : Server) -> Addr {
  ignore(self)
  abort("Server::addr not supported on wasm target")
}

///|
pub fn Server::close(self : Server) -> Unit {
  ignore(self)
}

///|
pub fn Server::close_graceful(
  self : Server,
  timeout_ms? : Int32,
) -> Unit raise HttpError {
  ignore(self)
  ignore(timeout_ms)
  raise HttpError::NotSupported
}

///|
pub fn Server::accept(
  self : Server,
) -> (ServerConnection, Addr) raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Server::run_forever(
  self : Server,
  _f : async (Request, &@io.BinaryReader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit raise HttpError {
  ignore(self)
  ignore(allow_failure)
  ignore(max_connections)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  ignore(self)
}

///|
pub fn ServerConnection::client_addr(self : ServerConnection) -> Addr {
  ignore(self)
  abort("ServerConnection::client_addr not supported on wasm target")
}

///|
pub fn ServerConnection::read_request(
  self : ServerConnection,
) -> Request raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::skip_request_body(
  self : ServerConnection,
) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::send_response(
  self : ServerConnection,
  _code : Int32,
  _reason : String,
  extra_headers? : Map[String, String],
  cookies~ : Array[Cookie] = [],
) -> Unit raise HttpError {
  ignore(self)
  ignore(extra_headers)
  ignore(cookies)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::flush(self : ServerConnection) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::end_response(
  self : ServerConnection,
) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::enter_passthrough_mode(
  self : ServerConnection,
) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
impl @io.BinaryReaderImpl for ServerConnection with fn get_controller(self) {
  ignore(self)
  abort("ServerConnection reader not supported on wasm target")
}

///|
impl @io.BinaryReaderImpl for ServerConnection with fn raw_read_impl(
  self,
  _buf,
  offset~,
  max_len~,
) {
  ignore(self)
  ignore(offset)
  ignore(max_len)
  raise HttpError::NotSupported
}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn raw_write_impl(
  self,
  _buf,
  offset~,
  len~,
) {
  ignore(self)
  ignore(offset)
  ignore(len)
  raise HttpError::NotSupported
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
  ignore(self)
  abort("writer not supported on this target")
}

///|
pub impl @io.BinaryWriter for ServerConnection

///|
pub extend ServerConnection with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn get_controller(self) {
  ignore(self)
  abort("writer not supported on this target")
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
impl @io.BinaryWriterImpl for Client with fn flush_partial_data(_self) {
  ()
}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn name(_self) {
  "ServerConnection"
}

///|
impl @io.BinaryWriterImpl for ServerConnection with fn flush_partial_data(_self) {
  ()
}
