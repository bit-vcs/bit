///|
pub async fn Addr::resolve(
  _host : String,
  port~ : Int32,
  protocol? : IpProtocolPreference,
) -> Addr raise ResolveHostnameError {
  ignore((port, protocol))
  raise ResolveHostnameError::ResolveHostnameError(
    "socket is not supported on wasm target",
  )
}

///|
pub struct Tcp {}

///|
pub fn Tcp::close(_self : Tcp) -> Unit {

}

///|
pub fn Tcp::fd(_self : Tcp) -> Int32 {
  -1
}

///|
pub fn Tcp::addr(_self : Tcp) -> Addr {
  abort("tcp is not supported on wasm target")
}

///|
pub async fn Tcp::connect(_addr : Addr) -> Tcp {
  abort("tcp is not supported on wasm target")
}

///|
pub async fn Tcp::connect_to_host(
  _host : StringView,
  port~ : Int32,
  protocol? : IpProtocolPreference,
) -> Tcp {
  ignore((port, protocol))
  abort("tcp is not supported on wasm target")
}

///|
pub fn Tcp::enable_keepalive(
  _self : Tcp,
  idle_before_keep_alive? : Int32,
  keep_alive_count? : Int32,
  keep_alive_interval? : Int32,
) -> Unit raise {
  ignore((idle_before_keep_alive, keep_alive_count, keep_alive_interval))
  raise Failure::Failure("tcp is not supported on wasm target")
}

///|
impl @io.BinaryReaderImpl for Tcp with fn get_controller(self) {
  ignore(self)
  @io.BinaryReaderController()
}

///|
impl @io.BinaryReaderImpl for Tcp with fn raw_read_impl(
  self,
  _buf,
  offset~,
  max_len~,
) {
  ignore((self, offset, max_len))
  abort("tcp is not supported on wasm target")
}

///|
impl @io.BinaryWriterImpl for Tcp with fn raw_write_impl(
  self,
  _buf,
  offset~,
  len~,
) {
  ignore((self, offset, len))
  abort("tcp is not supported on wasm target")
}

///|
pub struct TcpServer {}

///|
#alias(new, deprecated)
pub async fn TcpServer::TcpServer(
  _addr : Addr,
  dual_stack? : Bool,
  reuse_addr? : Bool,
) -> TcpServer {
  ignore((dual_stack, reuse_addr))
  abort("tcp is not supported on wasm target")
}

///|
pub fn TcpServer::close(_self : TcpServer) -> Unit {

}

///|
pub fn TcpServer::fd(_self : TcpServer) -> Int32 {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn TcpServer::addr(_self : TcpServer) -> Addr {
  abort("tcp is not supported on wasm target")
}

///|
pub async fn TcpServer::accept(_self : TcpServer) -> (Tcp, Addr) {
  abort("tcp is not supported on wasm target")
}

///|
pub async fn TcpServer::run_forever(
  _self : TcpServer,
  _f : async (Tcp, Addr) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  ignore((allow_failure, max_connections))
  abort("tcp is not supported on wasm target")
}

///|
pub struct UdpClient {}

///|
#alias(new, deprecated)
pub async fn UdpClient::UdpClient(_addr : Addr) -> UdpClient {
  abort("udp is not supported on wasm target")
}

///|
pub fn UdpClient::close(_self : UdpClient) -> Unit {

}

///|
pub fn UdpClient::fd(_self : UdpClient) -> Int32 {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn UdpClient::addr(_self : UdpClient) -> Addr {
  abort("udp is not supported on wasm target")
}

///|
pub fn UdpClient::connect(_self : UdpClient, _addr : Addr) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub async fn UdpClient::recv(
  _self : UdpClient,
  _buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> Int32 {
  ignore((offset, max_len))
  abort("udp is not supported on wasm target")
}

///|
pub async fn UdpClient::recvfrom(
  _self : UdpClient,
  _buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> (Int32, Addr) {
  ignore((offset, max_len))
  abort("udp is not supported on wasm target")
}

///|
pub async fn UdpClient::send(
  _self : UdpClient,
  _buf : Bytes,
  offset? : Int32,
  len? : Int32,
) -> Unit {
  ignore((offset, len))
  abort("udp is not supported on wasm target")
}

///|
pub fn UdpClient::set_multicast_interface(
  _self : UdpClient,
  _addr : Addr,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpClient::set_multicast_interface_v6(
  _self : UdpClient,
  _interface : String,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpClient::set_multicast_loopback(
  _self : UdpClient,
  _loopback : Bool,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpClient::set_multicast_ttl(
  _self : UdpClient,
  _ttl : Int32,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub struct UdpServer {}

///|
#alias(new, deprecated)
pub async fn UdpServer::UdpServer(
  _addr : Addr,
  dual_stack? : Bool,
) -> UdpServer {
  ignore(dual_stack)
  abort("udp is not supported on wasm target")
}

///|
pub async fn UdpServer::multicast(
  _multi_addr : Addr,
  interface_addr? : Addr,
) -> UdpServer {
  ignore(interface_addr)
  abort("udp is not supported on wasm target")
}

///|
pub fn UdpServer::close(_self : UdpServer) -> Unit {

}

///|
pub fn UdpServer::fd(_self : UdpServer) -> Int32 {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn UdpServer::addr(_self : UdpServer) -> Addr {
  abort("udp is not supported on wasm target")
}

///|
pub async fn UdpServer::recvfrom(
  _self : UdpServer,
  _buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> (Int32, Addr) {
  ignore((offset, max_len))
  abort("udp is not supported on wasm target")
}

///|
pub async fn UdpServer::sendto(
  _self : UdpServer,
  _buf : Bytes,
  _addr : Addr,
  offset? : Int32,
  len? : Int32,
) -> Unit {
  ignore((offset, len))
  abort("udp is not supported on wasm target")
}

///|
pub fn UdpServer::join_multicast_group(
  _self : UdpServer,
  _multi_addr : Addr,
  interface_addr? : Addr,
) -> Unit raise {
  ignore(interface_addr)
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpServer::join_multicast_group_v6(
  _self : UdpServer,
  _multi_addr : Addr,
  interface? : String,
) -> Unit raise {
  ignore(interface)
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpServer::set_multicast_interface(
  _self : UdpServer,
  _addr : Addr,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpServer::set_multicast_interface_v6(
  _self : UdpServer,
  _interface : String,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpServer::set_multicast_loopback(
  _self : UdpServer,
  _loopback : Bool,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub fn UdpServer::set_multicast_ttl(
  _self : UdpServer,
  _ttl : Int32,
) -> Unit raise {
  raise Failure::Failure("udp is not supported on wasm target")
}

///|
pub impl @io.BinaryReader for Tcp

///|
pub extend Tcp with @io.BinaryReader::{
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
pub impl @io.BinaryWriter for Tcp

///|
pub extend Tcp with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for Tcp with fn get_controller(self) {
  ignore(self)
  abort("writer not supported on this target")
}

///|
impl @io.BinaryReaderImpl for Tcp with fn name(_self) {
  "Tcp"
}

///|
impl @io.BinaryWriterImpl for Tcp with fn name(_self) {
  "Tcp"
}

///|
impl @io.BinaryWriterImpl for Tcp with fn flush_partial_data(_self) {
  ()
}
