///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
priv struct JsUdpAddr {
  host : String
  port : Int32
  family : Int32
}

///|
priv struct JsUdpSocketResult {
  id : Int32
  host : String
  port : Int32
  family : Int32
}

///|
priv struct JsUdpRecvResult {
  data : Bytes
  host : String
  port : Int32
  family : Int32
}

///|
async fn[T] run_js_promise(promise : JsPromise[T]) -> T {
  @js_async.run_promise(fn(_signal) { promise.cast() })
}

///|
fn addr_from_js(host : String, port : Int32, family : Int32) -> Addr {
  if family == 6 {
    Addr::{ host, port, ip: 0U, is_ipv6: true, }
  } else {
    Addr::parse("\{host}:\{port}") catch {
      _ => Addr::new(0U, port)
    }
  }
}

///|
fn addr_to_js(addr : Addr) -> JsUdpAddr {
  JsUdpAddr::{
    host: addr.host,
    port: addr.port,
    family: if addr.is_ipv6 {
      6
    } else {
      4
    },
  }
}

///|
extern "js" fn js_udp_resolve(
  host : String,
  port : Int32,
  protocol : Int32,
) -> JsPromise[JsUdpSocketResult] =
  #| async (host, port, protocol) => {
  #|   const dns = await import('node:dns/promises');
  #|   const family = protocol === 4 ? 4 : protocol === 6 ? 6 : 0;
  #|   const order = protocol === 46 ? 'ipv4first' : protocol === 64 ? 'ipv6first' : 'verbatim';
  #|   const result = await dns.lookup(host, { family, order });
  #|   return { id: 0, host: result.address, port: port | 0, family: result.family | 0 };
  #| }

///|
extern "js" fn js_udp_client_new(
  addr : JsUdpAddr,
) -> JsPromise[JsUdpSocketResult] =
  #| async (addr) => {
  #|   const dgram = await import('node:dgram');
  #|   const state = globalThis.__xudp ??= { nextId: 1, sockets: new Map() };
  #|   const socket = dgram.createSocket(addr.family === 6 ? 'udp6' : 'udp4');
  #|   const handle = { socket, q: [], waiters: [], closed: false };
  #|   socket.on('message', (msg, rinfo) => {
  #|     const item = { data: new Uint8Array(msg), host: rinfo.address, port: rinfo.port | 0, family: rinfo.family === 'IPv6' ? 6 : 4 };
  #|     const waiter = handle.waiters.shift();
  #|     if (waiter) waiter(item);
  #|     else handle.q.push(item);
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onError = (err) => { socket.off('connect', onConnect); reject(err); };
  #|     const onConnect = () => { socket.off('error', onError); resolve(); };
  #|     socket.once('error', onError);
  #|     socket.connect(addr.port, addr.host, onConnect);
  #|   });
  #|   const id = state.nextId++;
  #|   state.sockets.set(id, handle);
  #|   const local = socket.address();
  #|   return { id, host: local.address, port: local.port | 0, family: local.family === 'IPv6' ? 6 : 4 };
  #| }

///|
extern "js" fn js_udp_server_new(
  addr : JsUdpAddr,
  dual_stack : Bool,
) -> JsPromise[JsUdpSocketResult] =
  #| async (addr, dualStack) => {
  #|   const dgram = await import('node:dgram');
  #|   const state = globalThis.__xudp ??= { nextId: 1, sockets: new Map() };
  #|   const socket = dgram.createSocket({
  #|     type: addr.family === 6 ? 'udp6' : 'udp4',
  #|     ipv6Only: addr.family === 6 ? !dualStack : false,
  #|     reuseAddr: true,
  #|   });
  #|   const handle = { socket, q: [], waiters: [], closed: false };
  #|   socket.on('message', (msg, rinfo) => {
  #|     const item = { data: new Uint8Array(msg), host: rinfo.address, port: rinfo.port | 0, family: rinfo.family === 'IPv6' ? 6 : 4 };
  #|     const waiter = handle.waiters.shift();
  #|     if (waiter) waiter(item);
  #|     else handle.q.push(item);
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onError = (err) => { socket.off('listening', onListening); reject(err); };
  #|     const onListening = () => { socket.off('error', onError); resolve(); };
  #|     socket.once('error', onError);
  #|     socket.once('listening', onListening);
  #|     socket.bind(addr.port, addr.host);
  #|   });
  #|   const id = state.nextId++;
  #|   state.sockets.set(id, handle);
  #|   const local = socket.address();
  #|   return { id, host: local.address, port: local.port | 0, family: local.family === 'IPv6' ? 6 : 4 };
  #| }

///|
extern "js" fn js_udp_close(id : Int32) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xudp;
  #|   const handle = state?.sockets?.get(id);
  #|   if (!handle || handle.closed) return;
  #|   handle.closed = true;
  #|   state.sockets.delete(id);
  #|   const empty = { data: new Uint8Array(0), host: '', port: 0, family: 4 };
  #|   for (const waiter of handle.waiters.splice(0)) waiter(empty);
  #|   try { handle.socket.close(); } catch {}
  #| }

///|
extern "js" fn js_udp_recv(id : Int32) -> JsPromise[JsUdpRecvResult] =
  #| async (id) => {
  #|   const handle = globalThis.__xudp?.sockets?.get(id);
  #|   if (!handle) throw new Error('udp socket not found');
  #|   if (handle.q.length > 0) return handle.q.shift();
  #|   if (handle.closed) return { data: new Uint8Array(0), host: '', port: 0, family: 4 };
  #|   return await new Promise(resolve => handle.waiters.push(resolve));
  #| }

///|
extern "js" fn js_udp_send(
  id : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
) -> JsPromise[Unit] =
  #| async (id, data, offset, len) => {
  #|   const handle = globalThis.__xudp?.sockets?.get(id);
  #|   if (!handle) throw new Error('udp socket not found');
  #|   const payload = Buffer.from(data).subarray(offset, offset + len);
  #|   await new Promise((resolve, reject) => handle.socket.send(payload, (err) => err ? reject(err) : resolve()));
  #| }

///|
extern "js" fn js_udp_sendto(
  id : Int32,
  data : Bytes,
  addr : JsUdpAddr,
  offset : Int32,
  len : Int32,
) -> JsPromise[Unit] =
  #| async (id, data, addr, offset, len) => {
  #|   const handle = globalThis.__xudp?.sockets?.get(id);
  #|   if (!handle) throw new Error('udp socket not found');
  #|   const payload = Buffer.from(data).subarray(offset, offset + len);
  #|   await new Promise((resolve, reject) => handle.socket.send(payload, addr.port, addr.host, (err) => err ? reject(err) : resolve()));
  #| }

///|
extern "js" fn js_udp_connect(id : Int32, addr : JsUdpAddr) -> String =
  #| (id, addr) => {
  #|   try {
  #|     const handle = globalThis.__xudp?.sockets?.get(id);
  #|     if (!handle) throw new Error('udp socket not found');
  #|     handle.socket.connect(addr.port, addr.host);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_udp_set_multicast_ttl(id : Int32, ttl : Int32) -> String =
  #| (id, ttl) => {
  #|   try {
  #|     const handle = globalThis.__xudp?.sockets?.get(id);
  #|     if (!handle) throw new Error('udp socket not found');
  #|     handle.socket.setMulticastTTL(ttl);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_udp_set_multicast_loopback(
  id : Int32,
  loopback : Bool,
) -> String =
  #| (id, loopback) => {
  #|   try {
  #|     const handle = globalThis.__xudp?.sockets?.get(id);
  #|     if (!handle) throw new Error('udp socket not found');
  #|     handle.socket.setMulticastLoopback(loopback);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_udp_set_multicast_interface(
  id : Int32,
  address : String,
) -> String =
  #| (id, address) => {
  #|   try {
  #|     const handle = globalThis.__xudp?.sockets?.get(id);
  #|     if (!handle) throw new Error('udp socket not found');
  #|     handle.socket.setMulticastInterface(address);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_udp_join_multicast_group(
  id : Int32,
  multi_host : String,
  interface_host : String,
) -> String =
  #| (id, multiHost, interfaceHost) => {
  #|   try {
  #|     const handle = globalThis.__xudp?.sockets?.get(id);
  #|     if (!handle) throw new Error('udp socket not found');
  #|     handle.socket.addMembership(multiHost, interfaceHost || undefined);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
priv struct JsTcpAcceptResult {
  conn_id : Int32
  conn_host : String
  conn_port : Int32
  conn_family : Int32
  peer_host : String
  peer_port : Int32
  peer_family : Int32
}

///|
extern "js" fn js_tcp_connect(addr : JsUdpAddr) -> JsPromise[JsUdpSocketResult] =
  #| async (addr) => {
  #|   const net = await import('node:net');
  #|   const state = globalThis.__xtcp ??= { nextId: 1, conns: new Map(), servers: new Map() };
  #|   const registerConn = globalThis.__xtcpRegisterConn ??= (socket) => {
  #|     socket.setNoDelay(true);
  #|     const id = state.nextId++;
  #|     const handle = { socket, q: [], waiters: [], closed: false };
  #|     const resolveBytes = (waiter, chunk) => {
  #|       const maxLen = Math.max(0, waiter.maxLen | 0);
  #|       if (maxLen === 0 || chunk.length <= maxLen) {
  #|         waiter.resolve(new Uint8Array(chunk));
  #|       } else {
  #|         waiter.resolve(new Uint8Array(chunk.subarray(0, maxLen)));
  #|         handle.q.unshift(chunk.subarray(maxLen));
  #|       }
  #|     };
  #|     socket.on('data', (chunk) => {
  #|       const waiter = handle.waiters.shift();
  #|       if (waiter) resolveBytes(waiter, Buffer.from(chunk));
  #|       else handle.q.push(Buffer.from(chunk));
  #|     });
  #|     const close = () => {
  #|       if (handle.closed) return;
  #|       handle.closed = true;
  #|       for (const waiter of handle.waiters.splice(0)) waiter.resolve(new Uint8Array(0));
  #|     };
  #|     socket.once('end', close);
  #|     socket.once('close', close);
  #|     socket.once('error', close);
  #|     state.conns.set(id, handle);
  #|     return id;
  #|   };
  #|   const socket = net.createConnection({ host: addr.host, port: addr.port, family: addr.family || undefined });
  #|   await new Promise((resolve, reject) => {
  #|     const onError = (err) => { socket.off('connect', onConnect); reject(err); };
  #|     const onConnect = () => { socket.off('error', onError); resolve(); };
  #|     socket.once('error', onError);
  #|     socket.once('connect', onConnect);
  #|   });
  #|   const id = registerConn(socket);
  #|   return {
  #|     id,
  #|     host: socket.localAddress || addr.host,
  #|     port: socket.localPort | 0,
  #|     family: socket.localFamily === 'IPv6' ? 6 : 4,
  #|   };
  #| }

///|
extern "js" fn js_tcp_server_new(
  addr : JsUdpAddr,
  dual_stack : Bool,
  reuse_addr : Bool,
) -> JsPromise[JsUdpSocketResult] =
  #| async (addr, dualStack, reuseAddr) => {
  #|   const net = await import('node:net');
  #|   const state = globalThis.__xtcp ??= { nextId: 1, conns: new Map(), servers: new Map() };
  #|   if (!globalThis.__xtcpRegisterConn) {
  #|     globalThis.__xtcpRegisterConn = (socket) => {
  #|       socket.setNoDelay(true);
  #|       const id = state.nextId++;
  #|       const handle = { socket, q: [], waiters: [], closed: false };
  #|       const resolveBytes = (waiter, chunk) => {
  #|         const maxLen = Math.max(0, waiter.maxLen | 0);
  #|         if (maxLen === 0 || chunk.length <= maxLen) {
  #|           waiter.resolve(new Uint8Array(chunk));
  #|         } else {
  #|           waiter.resolve(new Uint8Array(chunk.subarray(0, maxLen)));
  #|           handle.q.unshift(chunk.subarray(maxLen));
  #|         }
  #|       };
  #|       socket.on('data', (chunk) => {
  #|         const waiter = handle.waiters.shift();
  #|         if (waiter) resolveBytes(waiter, Buffer.from(chunk));
  #|         else handle.q.push(Buffer.from(chunk));
  #|       });
  #|       const close = () => {
  #|         if (handle.closed) return;
  #|         handle.closed = true;
  #|         for (const waiter of handle.waiters.splice(0)) waiter.resolve(new Uint8Array(0));
  #|       };
  #|       socket.once('end', close);
  #|       socket.once('close', close);
  #|       socket.once('error', close);
  #|       state.conns.set(id, handle);
  #|       return id;
  #|     };
  #|   }
  #|   const server = net.createServer();
  #|   const id = state.nextId++;
  #|   const handle = { server, q: [], waiters: [], closed: false };
  #|   server.on('connection', (socket) => {
  #|     const connId = globalThis.__xtcpRegisterConn(socket);
  #|     const item = {
  #|       conn_id: connId,
  #|       conn_host: socket.localAddress || addr.host,
  #|       conn_port: socket.localPort | 0,
  #|       conn_family: socket.localFamily === 'IPv6' ? 6 : 4,
  #|       peer_host: socket.remoteAddress || '',
  #|       peer_port: socket.remotePort | 0,
  #|       peer_family: socket.remoteFamily === 'IPv6' ? 6 : 4,
  #|     };
  #|     const waiter = handle.waiters.shift();
  #|     if (waiter) waiter.resolve(item);
  #|     else handle.q.push(item);
  #|   });
  #|   await new Promise((resolve, reject) => {
  #|     const onError = (err) => { server.off('listening', onListening); reject(err); };
  #|     const onListening = () => { server.off('error', onError); resolve(); };
  #|     server.once('error', onError);
  #|     server.once('listening', onListening);
  #|     server.listen({
  #|       host: addr.host,
  #|       port: addr.port,
  #|       ipv6Only: addr.family === 6 ? !dualStack : false,
  #|       exclusive: !reuseAddr,
  #|     });
  #|   });
  #|   state.servers.set(id, handle);
  #|   const local = server.address();
  #|   return { id, host: local.address, port: local.port | 0, family: local.family === 'IPv6' ? 6 : 4 };
  #| }

///|
extern "js" fn js_tcp_accept(id : Int32) -> JsPromise[JsTcpAcceptResult] =
  #| async (id) => {
  #|   const handle = globalThis.__xtcp?.servers?.get(id);
  #|   if (!handle) throw new Error('tcp server not found');
  #|   if (handle.q.length > 0) return handle.q.shift();
  #|   if (handle.closed) throw new Error('tcp server closed');
  #|   return await new Promise((resolve, reject) => handle.waiters.push({ resolve, reject }));
  #| }

///|
extern "js" fn js_tcp_close(id : Int32) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xtcp;
  #|   const handle = state?.conns?.get(id);
  #|   if (!handle || handle.closed) return;
  #|   handle.closed = true;
  #|   state.conns.delete(id);
  #|   for (const waiter of handle.waiters.splice(0)) waiter.resolve(new Uint8Array(0));
  #|   try { handle.socket.destroy(); } catch {}
  #| }

///|
extern "js" fn js_tcp_server_close(id : Int32) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xtcp;
  #|   const handle = state?.servers?.get(id);
  #|   if (!handle || handle.closed) return;
  #|   handle.closed = true;
  #|   state.servers.delete(id);
  #|   for (const waiter of handle.waiters.splice(0)) waiter.reject(new Error('tcp server closed'));
  #|   try { handle.server.close(); } catch {}
  #| }

///|
extern "js" fn js_tcp_read(id : Int32, max_len : Int32) -> JsPromise[Bytes] =
  #| async (id, maxLen) => {
  #|   const handle = globalThis.__xtcp?.conns?.get(id);
  #|   if (!handle) throw new Error('tcp connection not found');
  #|   const take = (chunk) => {
  #|     maxLen = Math.max(0, maxLen | 0);
  #|     if (maxLen === 0 || chunk.length <= maxLen) return new Uint8Array(chunk);
  #|     handle.q.unshift(chunk.subarray(maxLen));
  #|     return new Uint8Array(chunk.subarray(0, maxLen));
  #|   };
  #|   if (handle.q.length > 0) return take(handle.q.shift());
  #|   if (handle.closed) return new Uint8Array(0);
  #|   return await new Promise((resolve, reject) => handle.waiters.push({ maxLen, resolve, reject }));
  #| }

///|
extern "js" fn js_tcp_write(
  id : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
) -> JsPromise[Int32] =
  #| async (id, data, offset, len) => {
  #|   const handle = globalThis.__xtcp?.conns?.get(id);
  #|   if (!handle) throw new Error('tcp connection not found');
  #|   const payload = Buffer.from(data).subarray(offset, offset + len);
  #|   if (payload.length === 0) return 0;
  #|   await new Promise((resolve, reject) => handle.socket.write(payload, (err) => err ? reject(err) : resolve()));
  #|   return payload.length | 0;
  #| }

///|
extern "js" fn js_tcp_enable_keepalive(
  id : Int32,
  idle_before_keep_alive : Int32,
) -> String =
  #| (id, idleBeforeKeepAlive) => {
  #|   try {
  #|     const handle = globalThis.__xtcp?.conns?.get(id);
  #|     if (!handle) throw new Error('tcp connection not found');
  #|     const initialDelay = Math.max(0, Number(idleBeforeKeepAlive || 0)) * 1000;
  #|     handle.socket.setKeepAlive(true, initialDelay);
  #|     return '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
fn protocol_to_js(protocol : IpProtocolPreference) -> Int32 {
  match protocol {
    OnlyV4 => 4
    OnlyV6 => 6
    FavorV4 => 46
    FavorV6 => 64
    NoPreference => 0
  }
}

///|
pub async fn Addr::resolve(
  host : String,
  port~ : Int32,
  protocol? : IpProtocolPreference,
) -> Addr raise ResolveHostnameError {
  let result = run_js_promise(
    js_udp_resolve(host, port, protocol_to_js(protocol.unwrap_or(NoPreference))),
  ) catch {
    err => raise ResolveHostnameError::ResolveHostnameError(err.to_string())
  }
  addr_from_js(result.host, result.port, result.family)
}

///|
pub struct Tcp {
  priv write_controller : @io.BinaryWriterController
  addr : Addr
  priv id : Int32
  priv read_buf : @io.BinaryReaderController
}

///|
pub fn Tcp::close(self : Tcp) -> Unit {
  js_tcp_close(self.id)
}

///|
pub fn Tcp::fd(_self : Tcp) -> Int32 {
  -1
}

///|
pub fn Tcp::addr(self : Tcp) -> Addr {
  self.addr
}

///|
pub async fn Tcp::connect(addr : Addr) -> Tcp {
  let result = run_js_promise(js_tcp_connect(addr_to_js(addr)))
  Tcp::{
    write_controller: @io.BinaryWriterController(),
    id: result.id,
    addr: addr_from_js(result.host, result.port, result.family),
    read_buf: @io.BinaryReaderController(),
  }
}

///|
pub async fn Tcp::connect_to_host(
  host : StringView,
  port~ : Int32,
  protocol? : IpProtocolPreference,
) -> Tcp {
  let addr = Addr::resolve(host.to_owned(), port~, protocol?)
  Tcp::connect(addr)
}

///|
pub fn Tcp::enable_keepalive(
  self : Tcp,
  idle_before_keep_alive? : Int32,
  keep_alive_count? : Int32,
  keep_alive_interval? : Int32,
) -> Unit raise {
  ignore((keep_alive_count, keep_alive_interval))
  let err = js_tcp_enable_keepalive(
    self.id,
    idle_before_keep_alive.unwrap_or(0),
  )
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
impl @io.BinaryReaderImpl for Tcp with fn get_controller(self) {
  self.read_buf
}

///|
impl @io.BinaryReaderImpl for Tcp with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  if max_len <= 0 {
    0
  } else {
    let data = run_js_promise(js_tcp_read(self.id, max_len)) catch {
      _ => return 0
    }
    let len = data.length()
    if len <= 0 {
      0
    } else {
      let n = if len < max_len { len } else { max_len }
      buf.blit_from_bytes(offset, data, 0, n)
      n
    }
  }
}

///|
impl @io.BinaryWriterImpl for Tcp with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  let available = buf.length() - offset
  let n = if len < available { len } else { available }
  if n <= 0 {
    0
  } else {
    run_js_promise(js_tcp_write(self.id, buf, offset, n))
  }
}

///|
pub struct TcpServer {
  addr : Addr
  priv id : Int32
}

///|
#alias(new, deprecated)
pub async fn TcpServer::TcpServer(
  addr : Addr,
  dual_stack? : Bool,
  reuse_addr? : Bool,
) -> TcpServer {
  let result = run_js_promise(
    js_tcp_server_new(
      addr_to_js(addr),
      dual_stack.unwrap_or(true),
      reuse_addr.unwrap_or(false),
    ),
  )
  TcpServer::{
    id: result.id,
    addr: addr_from_js(result.host, result.port, result.family),
  }
}

///|
pub fn TcpServer::close(self : TcpServer) -> Unit {
  js_tcp_server_close(self.id)
}

///|
pub fn TcpServer::fd(_self : TcpServer) -> Int32 {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn TcpServer::addr(self : TcpServer) -> Addr {
  self.addr
}

///|
pub async fn TcpServer::accept(self : TcpServer) -> (Tcp, Addr) {
  let result = run_js_promise(js_tcp_accept(self.id))
  (
    Tcp::{
      write_controller: @io.BinaryWriterController(),
      id: result.conn_id,
      addr: addr_from_js(result.conn_host, result.conn_port, result.conn_family),
      read_buf: @io.BinaryReaderController(),
    },
    addr_from_js(result.peer_host, result.peer_port, result.peer_family),
  )
}

///|
pub async fn TcpServer::run_forever(
  self : TcpServer,
  f : async (Tcp, Addr) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int32,
) -> Unit {
  defer self.close()
  let conn_limit = match max_connections {
    Some(n) => Some(@async.Semaphore(n))
    None => None
  }
  @async.with_task_group(group => {
    for ;; {
      let (conn, peer) = self.accept()
      if conn_limit is Some(limit) {
        limit.acquire()
      }
      group.spawn_bg(allow_failure=allow_failure.unwrap_or(true), () => {
        defer conn.close()
        if conn_limit is Some(limit) {
          defer limit.release()
          f(conn, peer)
        } else {
          f(conn, peer)
        }
      })
    }
  })
}

///|
fn copy_recv(
  result : JsUdpRecvResult,
  buf : FixedArray[Byte],
  offset : Int32,
  max_len : Int32,
) -> Int32 {
  let n = if result.data.length() < max_len {
    result.data.length()
  } else {
    max_len
  }
  buf.blit_from_bytes(offset, result.data, 0, n)
  n
}

///|
pub struct UdpClient {
  addr : Addr
  priv id : Int32
}

///|
#alias(new, deprecated)
pub async fn UdpClient::UdpClient(addr : Addr) -> UdpClient {
  let result = run_js_promise(js_udp_client_new(addr_to_js(addr)))
  UdpClient::{
    id: result.id,
    addr: addr_from_js(result.host, result.port, result.family),
  }
}

///|
pub fn UdpClient::close(self : UdpClient) -> Unit {
  js_udp_close(self.id)
}

///|
pub fn UdpClient::fd(_self : UdpClient) -> Int32 {
  -1
}

///|
#deprecated("use `.addr` instead")
pub fn UdpClient::addr(self : UdpClient) -> Addr {
  self.addr
}

///|
pub fn UdpClient::connect(self : UdpClient, addr : Addr) -> Unit raise {
  let err = js_udp_connect(self.id, addr_to_js(addr))
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub async fn UdpClient::recv(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> Int32 {
  let offset = offset.unwrap_or(0)
  let max_len = max_len.unwrap_or(buf.length() - offset)
  let result = run_js_promise(js_udp_recv(self.id))
  copy_recv(result, buf, offset, max_len)
}

///|
pub async fn UdpClient::recvfrom(
  self : UdpClient,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> (Int32, Addr) {
  let offset = offset.unwrap_or(0)
  let max_len = max_len.unwrap_or(buf.length() - offset)
  let result = run_js_promise(js_udp_recv(self.id))
  let n = copy_recv(result, buf, offset, max_len)
  (n, addr_from_js(result.host, result.port, result.family))
}

///|
pub async fn UdpClient::send(
  self : UdpClient,
  buf : Bytes,
  offset? : Int32,
  len? : Int32,
) -> Unit {
  let offset = offset.unwrap_or(0)
  let len = len.unwrap_or(buf.length() - offset)
  run_js_promise(js_udp_send(self.id, buf, offset, len))
}

///|
pub fn UdpClient::set_multicast_interface(
  self : UdpClient,
  addr : Addr,
) -> Unit raise {
  let err = js_udp_set_multicast_interface(self.id, addr.host)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpClient::set_multicast_interface_v6(
  self : UdpClient,
  interface : String,
) -> Unit raise {
  let err = js_udp_set_multicast_interface(self.id, interface)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpClient::set_multicast_loopback(
  self : UdpClient,
  loopback : Bool,
) -> Unit raise {
  let err = js_udp_set_multicast_loopback(self.id, loopback)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpClient::set_multicast_ttl(
  self : UdpClient,
  ttl : Int32,
) -> Unit raise {
  let err = js_udp_set_multicast_ttl(self.id, ttl)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub struct UdpServer {
  addr : Addr
  priv id : Int32
}

///|
#alias(new, deprecated)
pub async fn UdpServer::UdpServer(addr : Addr, dual_stack? : Bool) -> UdpServer {
  let result = run_js_promise(
    js_udp_server_new(addr_to_js(addr), dual_stack.unwrap_or(true)),
  )
  UdpServer::{
    id: result.id,
    addr: addr_from_js(result.host, result.port, result.family),
  }
}

///|
pub async fn UdpServer::multicast(
  multi_addr : Addr,
  interface_addr? : Addr,
) -> UdpServer {
  let server = UdpServer(Addr::new(0U, multi_addr.port))
  errdefer server.close()
  server.join_multicast_group(multi_addr, interface_addr?)
  server
}

///|
pub fn UdpServer::close(self : UdpServer) -> Unit {
  js_udp_close(self.id)
}

///|
pub fn UdpServer::fd(_self : UdpServer) -> Int32 {
  -1
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
  let offset = offset.unwrap_or(0)
  let max_len = max_len.unwrap_or(buf.length() - offset)
  let result = run_js_promise(js_udp_recv(self.id))
  let n = copy_recv(result, buf, offset, max_len)
  (n, addr_from_js(result.host, result.port, result.family))
}

///|
pub async fn UdpServer::sendto(
  self : UdpServer,
  buf : Bytes,
  addr : Addr,
  offset? : Int32,
  len? : Int32,
) -> Unit {
  let offset = offset.unwrap_or(0)
  let len = len.unwrap_or(buf.length() - offset)
  run_js_promise(js_udp_sendto(self.id, buf, addr_to_js(addr), offset, len))
}

///|
pub fn UdpServer::join_multicast_group(
  self : UdpServer,
  multi_addr : Addr,
  interface_addr? : Addr,
) -> Unit raise {
  let err = js_udp_join_multicast_group(
    self.id,
    multi_addr.host,
    interface_addr.map(fn(addr) { addr.host }).unwrap_or(""),
  )
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpServer::join_multicast_group_v6(
  self : UdpServer,
  multi_addr : Addr,
  interface? : String,
) -> Unit raise {
  let err = js_udp_join_multicast_group(
    self.id,
    multi_addr.host,
    interface.unwrap_or(""),
  )
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpServer::set_multicast_interface(
  self : UdpServer,
  addr : Addr,
) -> Unit raise {
  let err = js_udp_set_multicast_interface(self.id, addr.host)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpServer::set_multicast_interface_v6(
  self : UdpServer,
  interface : String,
) -> Unit raise {
  let err = js_udp_set_multicast_interface(self.id, interface)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpServer::set_multicast_loopback(
  self : UdpServer,
  loopback : Bool,
) -> Unit raise {
  let err = js_udp_set_multicast_loopback(self.id, loopback)
  if err != "" {
    raise Failure::Failure(err)
  }
}

///|
pub fn UdpServer::set_multicast_ttl(
  self : UdpServer,
  ttl : Int32,
) -> Unit raise {
  let err = js_udp_set_multicast_ttl(self.id, ttl)
  if err != "" {
    raise Failure::Failure(err)
  }
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
