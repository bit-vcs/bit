///|
pub async fn File::read(
  self : File,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> Int32 {
  @io.BinaryReader::read_into(self, buf, offset?, max_len?)
}

///|
pub async fn File::read_some(self : File, max_len? : Int32) -> Bytes? {
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
pub async fn File::drop(self : File, len : Int32) -> Int32 {
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
pub async fn File::read_until(self : File, sep : StringView) -> String? {
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
pub async fn File::read_all(self : File) -> &@data.Data {
  @io.BinaryReader::read_all(self)
}

///|
pub async fn File::write(self : File, data : &@data.Data) -> Unit {
  @io.BinaryWriter::write(self, data.binary()[:])
}

///|
pub async fn File::write_once(
  self : File,
  buf : Bytes,
  offset~ : Int32,
  len~ : Int32,
) -> Int32 {
  @io.BinaryWriterImpl::raw_write_impl(self, buf, offset~, len~)
}
