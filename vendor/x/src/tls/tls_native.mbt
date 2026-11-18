///|
pub struct Tls {
  priv write_controller : @io.BinaryWriterController
  priv read_controller : @io.BinaryReaderController
  priv inner : @async_tls.Tls
}

///|
fn to_async_trust(trust : TrustedRoot) -> @async_tls.TrustedRoot {
  match trust {
    NoVerification => @async_tls.NoVerification
    SystemRoot => @async_tls.SystemRoot
    CustomPemFile(file) => @async_tls.CustomPemFile(file)
  }
}

///|
fn[T] raise_tls_error(err : Error) -> T raise {
  let message = err.to_string()
  if err is @async_tls.ConnectionClosed {
    raise ConnectionClosed
  }
  raise TlsError(message)
}

///|
#borrow(buf)
extern "C" fn rand_bytes_ffi(buf : FixedArray[Byte], len : Int32) -> Int32 = "mizchi_x_tls_rand_bytes"

///|
/// Cryptographically secure random bytes from the OS (core's async/tls no
/// longer exposes `rand_bytes`).
pub fn rand_bytes(num : Int32) -> Bytes raise {
  if num < 0 {
    raise TlsError("rand_bytes length must be non-negative")
  }
  let buf = FixedArray::make(num, b'\x00')
  if rand_bytes_ffi(buf, num) != 0 {
    raise TlsError("rand_bytes: the OS random source failed")
  }
  Bytes::from_array(buf)
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
  let inner = @async_tls.Tls::client(
    inner,
    host?,
    sni~,
    trust=to_async_trust(trust),
  ) catch {
    err => raise_tls_error(err)
  }
  Tls::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    inner,
  }
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
  let trust = match trust {
    Some(trust) => trust
    None => if verify { SystemRoot } else { NoVerification }
  }
  let inner = @async_tls.Tls::client_from_pair(
    reader,
    writer,
    host?,
    sni~,
    trust=to_async_trust(trust),
  ) catch {
    err => raise_tls_error(err)
  }
  Tls::{
    write_controller: @io.BinaryWriterController(),
    read_controller: @io.BinaryReaderController(),
    inner,
  }
}

///|
pub async fn[Inner : @io.BinaryReader + @io.BinaryWriter] Tls::server(
  inner : Inner,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  ignore(
    (
      inner, private_key_file, private_key_type, certificate_file, certificate_type,
    ),
  )
  raise TlsError(
    "TLS server mode is not supported on the native target: moonbitlang/core async/tls is client-only",
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
  ignore(
    (
      reader, writer, private_key_file, private_key_type, certificate_file, certificate_type,
    ),
  )
  raise TlsError(
    "TLS server mode is not supported on the native target: moonbitlang/core async/tls is client-only",
  )
}

///|
pub fn Tls::close(self : Tls) -> Unit {
  self.inner.close()
}

///|
pub async fn Tls::shutdown(self : Tls) -> Unit {
  self.inner.shutdown() catch {
    err => raise_tls_error(err)
  }
}

///|
pub fn Tls::get_peer_certificate(self : Tls) -> Bytes? raise {
  self.inner.get_peer_certificate() catch {
    err => raise_tls_error(err)
  }
}

///|
pub fn Tls::unique_channel_binding(self : Tls) -> Bytes raise {
  self.inner.unique_channel_binding() catch {
    err => raise_tls_error(err)
  }
}

///|
pub fn Tls::server_endpoint_channel_binding(self : Tls) -> Bytes raise {
  self.inner.server_endpoint_channel_binding() catch {
    err => raise_tls_error(err)
  }
}

///|
impl @io.BinaryReaderImpl for Tls with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for Tls with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~) catch {
    err => raise_tls_error(err)
  }
}

///|
impl @io.BinaryWriterImpl for Tls with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len]) catch {
    err => raise_tls_error(err)
  }
  len
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
