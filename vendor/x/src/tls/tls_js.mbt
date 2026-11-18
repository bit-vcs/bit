///|
priv struct JsTlsChunk {
  ok : Bool
  data : Bytes
  error : String
  closed : Bool
}

///|
priv struct JsTlsStatus {
  secure : Bool
  ended : Bool
  error : String
}

///|
pub struct Tls {
  priv write_controller : @io.BinaryWriterController
  priv id : Int32
  priv reader : &@io.BinaryReader
  priv writer : &@io.BinaryWriter
  priv read_buf : @io.BinaryReaderController
  priv mut closed : Bool
}

///|
extern "js" fn js_tls_rand_bytes(num : Int32) -> Bytes =
  #| (num) => {
  #|   const crypto = require('node:crypto');
  #|   return new Uint8Array(crypto.randomBytes(Math.max(0, num | 0)));
  #| }

///|
extern "js" fn js_tls_create_client(
  host : String,
  servername : String,
  reject_unauthorized : Bool,
  ca_file : String,
) -> Int32 =
  #| (host, servername, rejectUnauthorized, caFile) => {
  #|   const fs = require('node:fs');
  #|   const tls = require('node:tls');
  #|   return globalThis.__xtlsCreate(false, {
  #|     host,
  #|     servername: servername || undefined,
  #|     rejectUnauthorized: !!rejectUnauthorized,
  #|     ca: caFile ? fs.readFileSync(caFile) : undefined,
  #|   });
  #| }

///|
extern "js" fn js_tls_create_server(
  private_key_file : String,
  private_key_type : Int32,
  certificate_file : String,
  certificate_type : Int32,
) -> Int32 =
  #| (privateKeyFile, privateKeyType, certificateFile, certificateType) => {
  #|   if (privateKeyType !== 1 || certificateType !== 1) {
  #|     throw new Error('only PEM key/certificate files are supported on js target');
  #|   }
  #|   const fs = require('node:fs');
  #|   return globalThis.__xtlsCreate(true, {
  #|     key: fs.readFileSync(privateKeyFile),
  #|     cert: fs.readFileSync(certificateFile),
  #|   });
  #| }

///|
extern "js" fn js_tls_init() -> Unit =
  #| () => {
  #|   if (globalThis.__xtls) return;
  #|   const { Duplex } = require('node:stream');
  #|   const tls = require('node:tls');
  #|   const crypto = require('node:crypto');
  #|   const state = globalThis.__xtls = { nextId: 1, handles: new Map() };
  #|   const makeChunk = (buf) => new Uint8Array(Buffer.from(buf));
  #|   const pemToDer = (cert) => {
  #|     const text = Buffer.isBuffer(cert) ? cert.toString('utf8') : String(cert ?? '');
  #|     const match = /-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----/s.exec(text);
  #|     if (match) return Buffer.from(match[1].replace(/\s+/g, ''), 'base64');
  #|     return Buffer.from(cert ?? []);
  #|   };
  #|   const fail = (handle, err) => {
  #|     const msg = String(err?.message ?? err ?? 'tls error');
  #|     if (!handle.error) handle.error = msg;
  #|   };
  #|   globalThis.__xtlsCreate = (isServer, options) => {
  #|     const handle = {
  #|       id: state.nextId++,
  #|       encryptedOut: [],
  #|       plainIn: [],
  #|       secure: false,
  #|       ended: false,
  #|       closed: false,
  #|       isServer: !!isServer,
  #|       localCertRaw: isServer && options?.cert ? pemToDer(options.cert) : null,
  #|       error: '',
  #|       socket: null,
  #|       transport: null,
  #|     };
  #|     const transport = new Duplex({
  #|       read() {},
  #|       write(chunk, _enc, cb) {
  #|         handle.encryptedOut.push(makeChunk(chunk));
  #|         cb();
  #|       },
  #|       final(cb) {
  #|         cb();
  #|       },
  #|     });
  #|     // tls.connect performs client certificate/hostname verification and
  #|     // supports generic Duplex transports; raw TLSSocket does neither here.
  #|     const socket = isServer
  #|       ? new tls.TLSSocket(transport, { isServer: true, secureContext: tls.createSecureContext(options) })
  #|       : tls.connect({ socket: transport, ...options });
  #|     handle.socket = socket;
  #|     handle.transport = transport;
  #|     socket.on(isServer ? 'secure' : 'secureConnect', () => { handle.secure = true; });
  #|     socket.on('data', chunk => handle.plainIn.push(makeChunk(chunk)));
  #|     socket.on('end', () => { handle.ended = true; });
  #|     socket.on('close', () => { handle.ended = true; handle.closed = true; });
  #|     socket.on('error', err => fail(handle, err));
  #|     transport.on('error', err => fail(handle, err));
  #|     state.handles.set(handle.id, handle);
  #|     return handle.id | 0;
  #|   };
  #|   globalThis.__xtlsTake = (id, key, maxLen = 0) => {
  #|     const handle = state.handles.get(id);
  #|     if (!handle) return { ok: false, data: new Uint8Array(0), error: 'tls handle not found', closed: true };
  #|     const q = handle[key];
  #|     if (q.length === 0) return { ok: false, data: new Uint8Array(0), error: handle.error, closed: handle.ended || handle.closed };
  #|     let chunk = Buffer.from(q.shift());
  #|     const limit = Math.max(0, maxLen | 0);
  #|     if (limit > 0 && chunk.length > limit) {
  #|       q.unshift(makeChunk(chunk.subarray(limit)));
  #|       chunk = chunk.subarray(0, limit);
  #|     }
  #|     return { ok: true, data: makeChunk(chunk), error: handle.error, closed: false };
  #|   };
  #|   globalThis.__xtlsCryptoHash = (id, which) => {
  #|     const handle = state.handles.get(id);
  #|     if (!handle) return null;
  #|     try {
  #|       if (which === 'unique') {
  #|         return handle.isServer
  #|           ? handle.socket.getPeerFinished?.() ?? null
  #|           : handle.socket.getFinished?.() ?? null;
  #|       }
  #|       if (which === 'peerFinished') return handle.socket.getPeerFinished?.() ?? null;
  #|       if (which === 'finished') return handle.socket.getFinished?.() ?? null;
  #|       const cert = handle.isServer
  #|         ? handle.socket.getCertificate?.() ?? null
  #|         : handle.socket.getPeerCertificate?.(true) ?? null;
  #|       const raw = cert?.raw ?? handle.localCertRaw;
  #|       if (raw) return crypto.createHash('sha256').update(raw).digest();
  #|     } catch {}
  #|     return null;
  #|   };
  #| }

///|
extern "js" fn js_tls_status(id : Int32) -> JsTlsStatus =
  #| (id) => {
  #|   const handle = globalThis.__xtls?.handles?.get(id);
  #|   if (!handle) return { secure: false, ended: true, error: 'tls handle not found' };
  #|   return { secure: !!handle.secure, ended: !!(handle.ended || handle.closed), error: handle.error || '' };
  #| }

///|
extern "js" fn js_tls_take_encrypted(id : Int32) -> JsTlsChunk =
  #| (id) => globalThis.__xtlsTake(id, 'encryptedOut')

///|
extern "js" fn js_tls_take_plain(id : Int32, max_len : Int32) -> JsTlsChunk =
  #| (id, maxLen) => globalThis.__xtlsTake(id, 'plainIn', maxLen)

///|
extern "js" fn js_tls_feed_encrypted(id : Int32, data : Bytes) -> String =
  #| (id, data) => {
  #|   try {
  #|     const handle = globalThis.__xtls?.handles?.get(id);
  #|     if (!handle) throw new Error('tls handle not found');
  #|     handle.transport.push(Buffer.from(data));
  #|     return handle.error || '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_tls_end_input(id : Int32) -> String =
  #| (id) => {
  #|   try {
  #|     const handle = globalThis.__xtls?.handles?.get(id);
  #|     if (!handle) throw new Error('tls handle not found');
  #|     handle.transport.push(null);
  #|     return handle.error || '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_tls_write_plain(
  id : Int32,
  data : Bytes,
  offset : Int32,
  len : Int32,
) -> String =
  #| (id, data, offset, len) => {
  #|   try {
  #|     const handle = globalThis.__xtls?.handles?.get(id);
  #|     if (!handle) throw new Error('tls handle not found');
  #|     const start = Math.max(0, offset | 0);
  #|     const end = Math.min(data.length, start + Math.max(0, len | 0));
  #|     if (end > start) handle.socket.write(Buffer.from(data).subarray(start, end));
  #|     return handle.error || '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_tls_shutdown(id : Int32) -> String =
  #| (id) => {
  #|   try {
  #|     const handle = globalThis.__xtls?.handles?.get(id);
  #|     if (!handle) return '';
  #|     handle.socket.end();
  #|     return handle.error || '';
  #|   } catch (err) {
  #|     return String(err?.message ?? err);
  #|   }
  #| }

///|
extern "js" fn js_tls_destroy(id : Int32) -> Unit =
  #| (id) => {
  #|   const state = globalThis.__xtls;
  #|   const handle = state?.handles?.get(id);
  #|   if (!handle) return;
  #|   state.handles.delete(id);
  #|   handle.closed = true;
  #|   try { handle.socket.destroy(); } catch {}
  #|   try { handle.transport.destroy(); } catch {}
  #| }

///|
extern "js" fn js_tls_peer_certificate(id : Int32) -> JsTlsChunk =
  #| (id) => {
  #|   const handle = globalThis.__xtls?.handles?.get(id);
  #|   if (!handle) return { ok: false, data: new Uint8Array(0), error: 'tls handle not found', closed: true };
  #|   try {
  #|     const cert = handle.socket.getPeerCertificate(true);
  #|     if (cert?.raw) return { ok: true, data: new Uint8Array(cert.raw), error: '', closed: false };
  #|     return { ok: false, data: new Uint8Array(0), error: '', closed: false };
  #|   } catch (err) {
  #|     return { ok: false, data: new Uint8Array(0), error: String(err?.message ?? err), closed: false };
  #|   }
  #| }

///|
extern "js" fn js_tls_channel_binding(id : Int32, which : String) -> JsTlsChunk =
  #| (id, which) => {
  #|   const data = globalThis.__xtlsCryptoHash(id, which);
  #|   if (!data) return { ok: false, data: new Uint8Array(0), error: 'channel binding is not available', closed: false };
  #|   return { ok: true, data: new Uint8Array(data), error: '', closed: false };
  #| }

///|
fn check_js_error(error : String) -> Unit raise {
  if error != "" {
    raise TlsError(error)
  }
}

///|
fn file_type_to_int(t : X509FileType) -> Int32 {
  match t {
    PEM => 1
    ANS1 => 2
  }
}

///|
fn trust_to_js(verify : Bool, trust? : TrustedRoot) -> (Bool, String) {
  match trust {
    Some(NoVerification) => (false, "")
    Some(SystemRoot) => (true, "")
    Some(CustomPemFile(file)) => (true, file)
    None => (verify, "")
  }
}

///|
fn sni_to_js(host? : String, sni : Bool) -> String {
  if sni {
    host.unwrap_or("")
  } else {
    ""
  }
}

///|
pub fn rand_bytes(num : Int32) -> Bytes raise {
  if num < 0 {
    raise TlsError("rand_bytes length must be non-negative")
  }
  js_tls_rand_bytes(num)
}

///|
extern "js" fn js_tls_tick() -> @js_async.Promise[Unit] =
  #| () => new Promise(resolve => setImmediate(resolve))

///|
async fn Tls::flush_encrypted(self : Tls) -> Unit {
  // Node emits TLS records and secure/data/end events on its event loop.
  // Process those callbacks before deciding to block on the peer's input.
  js_tls_tick().wait()
  while true {
    let chunk = js_tls_take_encrypted(self.id)
    check_js_error(chunk.error)
    if chunk.ok {
      self.writer.write(chunk.data) catch {
        TransportError(@io.PipeClosed, ..) => raise ConnectionClosed
        err => raise TlsError((err : Error).to_string())
      }
    } else {
      break
    }
  }
}

///|
async fn Tls::read_underlying_once(self : Tls) -> Bool {
  let data = self.reader.read() catch {
    TransportError(@io.PipeClosed, ..) => raise ConnectionClosed
    err => raise TlsError((err : Error).to_string())
  }
  match data {
    Some(data) => {
      check_js_error(js_tls_feed_encrypted(self.id, data))
      true
    }
    None => {
      check_js_error(js_tls_end_input(self.id))
      false
    }
  }
}

///|
fn Tls::status(self : Tls) -> JsTlsStatus raise {
  let status = js_tls_status(self.id)
  check_js_error(status.error)
  status
}

///|
async fn Tls::drive_handshake(self : Tls) -> Unit {
  let mut steps = 0
  while true {
    self.flush_encrypted()
    let status = self.status()
    if status.secure {
      break
    }
    if status.ended {
      raise ConnectionClosed
    }
    if !self.read_underlying_once() {
      raise ConnectionClosed
    }
    steps += 1
    if steps > 10000 {
      raise TlsError("tls handshake did not complete")
    }
  }
  self.flush_encrypted()
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[Inner : @io.BinaryReader + @io.BinaryWriter] Tls::client(
  inner : Inner,
  verify~ : Bool = true,
  host? : String,
  sni~ : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  let trust = match trust {
    Some(trust) => trust
    None => if verify { SystemRoot } else { NoVerification }
  }
  Tls::client_from_pair(inner, inner, host?, sni~, trust~)
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[R : @io.BinaryReader, W : @io.BinaryWriter] Tls::client_from_pair(
  reader : R,
  writer : W,
  verify~ : Bool = true,
  host? : String,
  sni~ : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  js_tls_init()
  let (reject_unauthorized, ca_file) = trust_to_js(verify, trust?)
  let id = js_tls_create_client(
    host.unwrap_or(""),
    sni_to_js(host?, sni),
    reject_unauthorized,
    ca_file,
  )
  let tls = Tls::{
    write_controller: @io.BinaryWriterController(),
    id,
    reader,
    writer,
    read_buf: @io.BinaryReaderController(),
    closed: false,
  }
  errdefer tls.close()
  tls.drive_handshake()
  tls
}

///|
pub async fn[Inner : @io.BinaryReader + @io.BinaryWriter] Tls::server(
  inner : Inner,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  Tls::server_from_pair(
    inner,
    inner,
    private_key_file~,
    private_key_type~,
    certificate_file~,
    certificate_type~,
  )
}

///|
pub async fn[R : @io.BinaryReader, W : @io.BinaryWriter] Tls::server_from_pair(
  reader : R,
  writer : W,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  js_tls_init()
  let id = js_tls_create_server(
    private_key_file,
    file_type_to_int(private_key_type),
    certificate_file,
    file_type_to_int(certificate_type),
  )
  let tls = Tls::{
    write_controller: @io.BinaryWriterController(),
    id,
    reader,
    writer,
    read_buf: @io.BinaryReaderController(),
    closed: false,
  }
  errdefer tls.close()
  tls.drive_handshake()
  tls
}

///|
pub fn Tls::close(self : Tls) -> Unit {
  if !self.closed {
    js_tls_destroy(self.id)
    self.closed = true
  }
}

///|
pub async fn Tls::shutdown(self : Tls) -> Unit {
  js_tls_tick().wait()
  if !self.closed && !self.status().ended {
    check_js_error(js_tls_shutdown(self.id))
    self.flush_encrypted()
  }
}

///|
pub fn Tls::get_peer_certificate(self : Tls) -> Bytes? raise {
  let cert = js_tls_peer_certificate(self.id)
  check_js_error(cert.error)
  if cert.ok {
    Some(cert.data)
  } else {
    None
  }
}

///|
pub fn Tls::unique_channel_binding(self : Tls) -> Bytes raise {
  let binding = js_tls_channel_binding(self.id, "unique")
  check_js_error(binding.error)
  binding.data
}

///|
pub fn Tls::server_endpoint_channel_binding(self : Tls) -> Bytes raise {
  let binding = js_tls_channel_binding(self.id, "serverEndpoint")
  check_js_error(binding.error)
  binding.data
}

///|
impl @io.BinaryReaderImpl for Tls with fn get_controller(self) {
  self.read_buf
}

///|
impl @io.BinaryReaderImpl for Tls with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  if self.closed || max_len <= 0 {
    return 0
  }
  let mut result = 0
  let mut done = false
  while !done {
    self.flush_encrypted() catch {
      _ => return 0
    }
    let chunk = js_tls_take_plain(self.id, max_len)
    if chunk.error != "" {
      return 0
    }
    if chunk.ok {
      let n = @cmp.minimum(chunk.data.length(), max_len)
      buf.blit_from_bytes(offset, chunk.data, 0, n)
      result = n
      done = true
    } else {
      let status = self.status() catch { _ => return 0 }
      if status.ended || chunk.closed {
        done = true
      } else {
        let ok = self.read_underlying_once() catch { _ => return 0 }
        if !ok {
          done = true
        }
      }
    }
  }
  result
}

///|
impl @io.BinaryWriterImpl for Tls with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  if self.closed {
    raise ConnectionClosed
  }
  let available = buf.length() - offset
  let n = @cmp.minimum(len, available)
  if n <= 0 {
    return 0
  }
  let err = js_tls_write_plain(self.id, buf, offset, n)
  check_js_error(err)
  self.flush_encrypted()
  n
}

///|
pub impl @io.BinaryReader for Tls

///|
pub extend Tls with @io.BinaryReader::{
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
pub impl @io.BinaryWriter for Tls

///|
pub extend Tls with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for Tls with fn get_controller(self) {
  self.write_controller
}

///|
impl @io.BinaryReaderImpl for Tls with fn name(_self) {
  "Tls"
}

///|
impl @io.BinaryWriterImpl for Tls with fn name(_self) {
  "Tls"
}

///|
impl @io.BinaryWriterImpl for Tls with fn flush_partial_data(_self) {
  ()
}
