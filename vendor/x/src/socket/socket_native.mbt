///|
fn to_async_protocol(
  protocol : IpProtocolPreference,
) -> @async_socket.IpProtocolPreference {
  match protocol {
    OnlyV4 => @async_socket.OnlyV4
    OnlyV6 => @async_socket.OnlyV6
    FavorV4 => @async_socket.FavorV4
    FavorV6 => @async_socket.FavorV6
    NoPreference => @async_socket.NoPreference
  }
}

///|
fn Addr::to_async(self : Addr) -> @async_socket.Addr raise InvalidAddr {
  @async_socket.Addr::parse(self.to_string()) catch {
    _ => raise InvalidAddr
  }
}

///|
fn addr_from_async(addr : @async_socket.Addr) -> Addr {
  Addr::parse("\{addr}") catch {
    _ =>
      match addr.ip {
        Ipv6(_) =>
          Addr::{ host: "::", port: addr.port.to_int(), ip: 0U, is_ipv6: true, }
        Ipv4(ip) => Addr::new(ip, addr.port.to_int())
      }
  }
}

///|
pub async fn Addr::resolve(
  host : String,
  port~ : Int32,
  protocol? : IpProtocolPreference,
) -> Addr raise ResolveHostnameError {
  let protocol = to_async_protocol(protocol.unwrap_or(NoPreference))
  let addr = @async_socket.Addr::resolve(host, port=port.to_uint16(), protocol~) catch {
    err => raise ResolveHostnameError::ResolveHostnameError(err.to_string())
  }
  addr_from_async(addr)
}

///|
pub struct Tcp {
  priv write_controller : @io.BinaryWriterController
  priv read_controller : @io.BinaryReaderController
  addr : Addr
  priv inner : @async_socket.Tcp
}

///|
pub fn Tcp::close(self : Tcp) -> Unit {
  self.inner.close()
}

///|
pub fn Tcp::fd(self : Tcp) -> Int32 {
  socket_fd_to_int(self.inner.fd())
}

///|
pub fn Tcp::addr(self : Tcp) -> Addr {
  self.addr
}

///|
pub async fn Tcp::connect(addr : Addr) -> Tcp {
  let inner = @async_socket.Tcp::connect(
    addr.to_async() catch {
      _ => abort("@socket.Tcp::connect: invalid address")
    },
  )
  Tcp::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    addr: addr_from_async(inner.addr),
    inner,
  }
}

///|
pub async fn Tcp::connect_to_host(
  host : StringView,
  port~ : Int32,
  protocol? : IpProtocolPreference,
) -> Tcp {
  let inner = @async_socket.Tcp::connect_to_host(
    host,
    port=port.to_uint16(),
    protocol=to_async_protocol(protocol.unwrap_or(NoPreference)),
  )
  Tcp::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    addr: addr_from_async(inner.addr),
    inner,
  }
}

///|
pub fn Tcp::enable_keepalive(
  self : Tcp,
  idle_before_keep_alive? : Int32,
  keep_alive_count? : Int32,
  keep_alive_interval? : Int32,
) -> Unit raise {
  self.inner.enable_keepalive(
    idle_before_keep_alive?,
    keep_alive_count?,
    keep_alive_interval?,
  )
}

///|
impl @io.BinaryReaderImpl for Tcp with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for Tcp with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
impl @io.BinaryWriterImpl for Tcp with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub struct TcpServer {
  addr : Addr
  priv inner : @async_socket.TcpServer
}

///|
#alias(new, deprecated)
pub async fn TcpServer::TcpServer(
  addr : Addr,
  dual_stack? : Bool,
  reuse_addr? : Bool,
) -> TcpServer {
  let inner = @async_socket.TcpServer(
    addr.to_async() catch {
      _ => abort("@socket.TcpServer: invalid address")
    },
    dual_stack?,
    reuse_addr?,
  )
  TcpServer::{ addr: addr_from_async(inner.addr), inner, }
}

///|
pub fn TcpServer::close(self : TcpServer) -> Unit {
  self.inner.close()
}

///|
pub fn TcpServer::fd(self : TcpServer) -> Int32 {
  socket_fd_to_int(self.inner.fd())
}

///|
#deprecated("use `.addr` instead")
pub fn TcpServer::addr(self : TcpServer) -> Addr {
  self.addr
}

///|
pub async fn TcpServer::accept(self : TcpServer) -> (Tcp, Addr) {
  let (conn, peer) = self.inner.accept()
  (
    Tcp::{
      write_controller: @io.BinaryWriterController(),
      read_controller: @io.BinaryReaderController(),
      addr: addr_from_async(conn.addr),
      inner: conn,
    },
    addr_from_async(peer),
  )
}

///|
pub async fn TcpServer::run_forever(
  self : TcpServer,
  f : async (Tcp, Addr) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  self.inner.run_forever(
    (conn, peer) => {
      f(
        Tcp::{
          write_controller: @io.BinaryWriterController(),
          read_controller: @io.BinaryReaderController(),
          addr: addr_from_async(conn.addr),
          inner: conn,
        },
        addr_from_async(peer),
      )
    },
    allow_failure?,
    max_connections?,
  )
}

///|
pub struct UdpClient {
  addr : Addr
  priv inner : @async_socket.UdpClient
}

///|
#alias(new, deprecated)
pub async fn UdpClient::UdpClient(addr : Addr) -> UdpClient {
  let inner = @async_socket.UdpClient(
    addr.to_async() catch {
      _ => abort("@socket.UdpClient: invalid address")
    },
  )
  UdpClient::{ addr: addr_from_async(inner.addr), inner, }
}

///|
pub fn UdpClient::close(self : UdpClient) -> Unit {
  self.inner.close()
}

///|
pub fn UdpClient::fd(self : UdpClient) -> Int32 {
  socket_fd_to_int(self.inner.fd())
}

///|
#deprecated("use `.addr` instead")
pub fn UdpClient::addr(self : UdpClient) -> Addr {
  self.addr
}

///|
pub fn UdpClient::connect(self : UdpClient, addr : Addr) -> Unit raise {
  self.inner.connect(addr.to_async())
}

///|
pub async fn UdpClient::recv(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> Int32 {
  self.inner.recv_into(buf, offset?, max_len?)
}

///|
pub async fn UdpClient::recvfrom(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> (Int32, Addr) {
  let (n, addr) = self.inner.recv_into_with_addr(buf, offset?, max_len?)
  (n, addr_from_async(addr))
}

///|
pub async fn UdpClient::send(
  self : UdpClient,
  buf : Bytes,
  offset? : Int32,
  len? : Int32,
) -> Unit {
  self.inner.send(buf, offset?, len?)
}

///|
pub fn UdpClient::set_multicast_interface(
  self : UdpClient,
  addr : Addr,
) -> Unit raise {
  self.inner.set_multicast_interface(addr.to_async().ip)
}

///|
pub fn UdpClient::set_multicast_interface_v6(
  self : UdpClient,
  interface : String,
) -> Unit raise {
  self.inner.set_multicast_interface_v6(interface)
}

///|
pub fn UdpClient::set_multicast_loopback(
  self : UdpClient,
  loopback : Bool,
) -> Unit raise {
  self.inner.set_multicast_loopback(loopback)
}

///|
pub fn UdpClient::set_multicast_ttl(
  self : UdpClient,
  ttl : Int32,
) -> Unit raise {
  self.inner.set_multicast_ttl(ttl)
}

///|
pub struct UdpServer {
  addr : Addr
  priv inner : @async_socket.UdpServer
}

///|
#alias(new, deprecated)
pub async fn UdpServer::UdpServer(addr : Addr, dual_stack? : Bool) -> UdpServer {
  let inner = @async_socket.UdpServer(
    addr.to_async() catch {
      _ => abort("@socket.UdpServer: invalid address")
    },
    dual_stack?,
  )
  UdpServer::{ addr: addr_from_async(inner.addr), inner, }
}

///|
pub async fn UdpServer::multicast(
  multi_addr : Addr,
  interface_addr? : Addr,
) -> UdpServer {
  let inner = @async_socket.UdpServer::multicast(
    multi_addr.to_async() catch {
      _ => abort("@socket.UdpServer::multicast: invalid address")
    },
    interface_addr?=match interface_addr {
      Some(addr) =>
        Some(
          (addr.to_async() catch {
            _ =>
              abort("@socket.UdpServer::multicast: invalid interface address")
          }).ip,
        )
      None => None
    },
  )
  UdpServer::{ addr: addr_from_async(inner.addr), inner, }
}

///|
pub fn UdpServer::close(self : UdpServer) -> Unit {
  self.inner.close()
}

///|
pub fn UdpServer::fd(self : UdpServer) -> Int32 {
  socket_fd_to_int(self.inner.fd())
}

///|
#deprecated("use `.addr` instead")
pub fn UdpServer::addr(self : UdpServer) -> Addr {
  self.addr
}

///|
pub async fn UdpServer::recvfrom(
  self : UdpServer,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> (Int32, Addr) {
  let (n, addr) = self.inner.recv_into(buf, offset?, max_len?)
  (n, addr_from_async(addr))
}

///|
pub async fn UdpServer::sendto(
  self : UdpServer,
  buf : Bytes,
  addr : Addr,
  offset? : Int32,
  len? : Int32,
) -> Unit {
  self.inner.send(
    buf,
    addr.to_async() catch {
      _ => abort("@socket.UdpServer::sendto: invalid address")
    },
    offset?,
    len?,
  )
}

///|
pub fn UdpServer::join_multicast_group(
  self : UdpServer,
  multi_addr : Addr,
  interface_addr? : Addr,
) -> Unit raise {
  self.inner.join_multicast_group(
    multi_addr.to_async(),
    interface_addr?=match interface_addr {
      Some(addr) => Some(addr.to_async().ip)
      None => None
    },
  )
}

///|
pub fn UdpServer::join_multicast_group_v6(
  self : UdpServer,
  multi_addr : Addr,
  interface? : String,
) -> Unit raise {
  self.inner.join_multicast_group_v6(multi_addr.to_async(), interface?)
}

///|
pub fn UdpServer::set_multicast_interface(
  self : UdpServer,
  addr : Addr,
) -> Unit raise {
  self.inner.set_multicast_interface(addr.to_async().ip)
}

///|
pub fn UdpServer::set_multicast_interface_v6(
  self : UdpServer,
  interface : String,
) -> Unit raise {
  self.inner.set_multicast_interface_v6(interface)
}

///|
pub fn UdpServer::set_multicast_loopback(
  self : UdpServer,
  loopback : Bool,
) -> Unit raise {
  self.inner.set_multicast_loopback(loopback)
}

///|
pub fn UdpServer::set_multicast_ttl(
  self : UdpServer,
  ttl : Int32,
) -> Unit raise {
  self.inner.set_multicast_ttl(ttl)
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
  self.write_controller
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
