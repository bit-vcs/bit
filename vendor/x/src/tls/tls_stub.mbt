///|
pub struct Tls {}

///|
pub fn rand_bytes(_num : Int32) -> Bytes raise {
  raise TlsError("tls rand_bytes is not supported on this target")
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[Inner : @io.BinaryReader + @io.BinaryWriter] Tls::client(
  _inner : Inner,
  verify~ : Bool = true,
  host? : String,
  sni~ : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  ignore((verify, host, sni, trust))
  abort("tls is not supported on this target")
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[R : @io.BinaryReader, W : @io.BinaryWriter] Tls::client_from_pair(
  _reader : R,
  _writer : W,
  verify~ : Bool = true,
  host? : String,
  sni~ : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  ignore((verify, host, sni, trust))
  abort("tls is not supported on this target")
}

///|
pub async fn[Inner : @io.BinaryReader + @io.BinaryWriter] Tls::server(
  _inner : Inner,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  ignore(
    (private_key_file, private_key_type, certificate_file, certificate_type),
  )
  abort("tls is not supported on this target")
}

///|
pub async fn[R : @io.BinaryReader, W : @io.BinaryWriter] Tls::server_from_pair(
  _reader : R,
  _writer : W,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  ignore(
    (private_key_file, private_key_type, certificate_file, certificate_type),
  )
  abort("tls is not supported on this target")
}

///|
pub fn Tls::close(_self : Tls) -> Unit {
  ()
}

///|
pub async fn Tls::shutdown(_self : Tls) -> Unit {
  ()
}

///|
pub fn Tls::get_peer_certificate(_self : Tls) -> Bytes? raise {
  raise TlsError("tls is not supported on this target")
}

///|
pub fn Tls::unique_channel_binding(_self : Tls) -> Bytes raise {
  raise TlsError("tls is not supported on this target")
}

///|
pub fn Tls::server_endpoint_channel_binding(_self : Tls) -> Bytes raise {
  raise TlsError("tls is not supported on this target")
}

///|
impl @io.BinaryReaderImpl for Tls with fn get_controller(_self) {
  @io.BinaryReaderController()
}

///|
impl @io.BinaryReaderImpl for Tls with fn raw_read_impl(
  _self,
  _buf,
  offset~,
  max_len~,
) {
  ignore((offset, max_len))
  abort("tls is not supported on this target")
}

///|
impl @io.BinaryWriterImpl for Tls with fn raw_write_impl(
  _self,
  _buf,
  offset~,
  len~,
) {
  ignore((offset, len))
  abort("tls is not supported on this target")
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
  ignore(self)
  abort("writer not supported on this target")
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
