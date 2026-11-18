///|
pub async fn Tls::read(
  self : Tls,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> Int32 {
  @io.BinaryReader::read_into(self, buf, offset?, max_len?)
}

///|
pub async fn Tls::read_some(self : Tls, max_len? : Int32) -> Bytes? {
  match max_len {
    None => @io.BinaryReader::read(self)
    Some(max_len) =>
      match @io.BinaryReader::peek(self) {
        None => None
        Some(chunk) => {
          let len = if max_len < chunk.length() {
            max_len
          } else {
            chunk.length()
          }
          let bytes = chunk[:len].to_owned()
          @io.BinaryReader::drop_exactly(self, len)
          Some(bytes)
        }
      }
  }
}

///|
pub async fn Tls::drop(self : Tls, len : Int32) -> Int32 {
  for dropped = 0; dropped < len; {
    match @io.BinaryReader::peek(self) {
      None => break dropped
      Some(chunk) => {
        let remaining = len - dropped
        let count = if remaining < chunk.length() {
          remaining
        } else {
          chunk.length()
        }
        @io.BinaryReader::drop_exactly(self, count)
        continue dropped + count
      }
    }
  } nobreak {
    len
  }
}

///|
pub async fn Tls::read_until(self : Tls, sep : StringView) -> String? {
  let pattern : &@data.Data = sep
  match
    @io.BinaryReader::read_until(
      self,
      pattern.binary()[:],
      include_delimiter=false,
    ) {
    None => None
    Some(bytes) => Some(@data.Data::text(bytes))
  }
}

///|
pub async fn Tls::read_all(self : Tls) -> &@data.Data {
  @io.BinaryReader::read_all(self)
}

///|
pub async fn Tls::write(self : Tls, data : &@data.Data) -> Unit {
  @io.BinaryWriter::write(self, data.binary()[:])
}

///|
pub async fn Tls::write_once(
  self : Tls,
  buf : Bytes,
  offset~ : Int32,
  len~ : Int32,
) -> Int32 {
  @io.BinaryWriterImpl::raw_write_impl(self, buf, offset~, len~)
}
