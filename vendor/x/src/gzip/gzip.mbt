///|
pub struct Decoder[R] {
  priv read_controller : @io.BinaryReaderController
  priv inner : @async_gzip.Decoder[R]
}

///|
#alias(new, deprecated)
pub fn[R] Decoder::Decoder(inner : R) -> Decoder[R] {
  Decoder::{
    read_controller: @io.BinaryReaderController(),
    inner: @async_gzip.Decoder(inner),
  }
}

///|
impl[R : @io.BinaryReader] @io.BinaryReaderImpl for Decoder[R] with fn get_controller(
  self,
) {
  self.read_controller
}

///|
impl[R : @io.BinaryReader] @io.BinaryReaderImpl for Decoder[R] with fn raw_read_impl(
  self,
  dst,
  offset~,
  max_len~,
) {
  self.inner.read_into(dst, offset~, max_len~)
}

///|
pub struct Encoder[W] {
  priv write_controller : @io.BinaryWriterController
  priv inner : @async_gzip.Encoder[W]
}

///|
#alias(new, deprecated)
pub fn[W] Encoder::Encoder(
  inner : W,
  mtime~ : UInt32 = 0U,
  extra_flags~ : Byte = b'\x00',
  operating_system~ : Byte = b'\xff',
) -> Encoder[W] {
  {
    write_controller: @io.BinaryWriterController(),
    inner: @async_gzip.Encoder(inner, mtime~, extra_flags~, operating_system~),
  }
}

///|
pub async fn[W : @io.BinaryWriter] Encoder::flush(self : Encoder[W]) -> Unit {
  self.inner.flush_partial_data()
}

///|
pub async fn[W : @io.BinaryWriter] Encoder::end(self : Encoder[W]) -> Unit {
  self.inner.end()
}

///|
impl[W : @io.BinaryWriter] @io.BinaryWriterImpl for Encoder[W] with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub impl[R : @io.BinaryReader] @io.BinaryReader for Decoder[R]

///|
pub extend Decoder with @io.BinaryReader::{
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
pub impl[W : @io.BinaryWriter] @io.BinaryWriter for Encoder[W]

///|
pub extend Encoder with @io.BinaryWriter::{write_reader}

///|
impl[W : @io.BinaryWriter] @io.BinaryWriterImpl for Encoder[W] with fn get_controller(
  self,
) {
  self.write_controller
}

///|
impl[R : @io.BinaryReader] @io.BinaryReaderImpl for Decoder[R] with fn name(
  _self,
) {
  "@gzip.Decoder"
}

///|
impl[W : @io.BinaryWriter] @io.BinaryWriterImpl for Encoder[W] with fn name(
  _self,
) {
  "@gzip.Encoder"
}

///|
impl[W : @io.BinaryWriter] @io.BinaryWriterImpl for Encoder[W] with fn flush_partial_data(
  self,
) {
  self.inner.flush_partial_data()
}
