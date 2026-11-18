///|
pub async fn ReadFromProcess::read(
  self : ReadFromProcess,
  buf : FixedArray[Byte],
  offset? : Int32,
  max_len? : Int32,
) -> Int32 {
  @async_io.BinaryReader::read_into(self, buf, offset?, max_len?)
}

///|
pub async fn ReadFromProcess::read_some(
  self : ReadFromProcess,
  max_len? : Int32,
) -> Bytes? {
  match max_len {
    None => @async_io.BinaryReader::read(self)
    Some(max_len) =>
      match @async_io.BinaryReader::peek(self) {
        None => None
        Some(chunk) => {
          let len = if max_len < chunk.length() {
            max_len
          } else {
            chunk.length()
          }
          let bytes = chunk[:len].to_owned()
          @async_io.BinaryReader::drop_exactly(self, len)
          Some(bytes)
        }
      }
  }
}

///|
pub async fn ReadFromProcess::drop(
  self : ReadFromProcess,
  len : Int32,
) -> Int32 {
  for dropped = 0; dropped < len; {
    match @async_io.BinaryReader::peek(self) {
      None => break dropped
      Some(chunk) => {
        let remaining = len - dropped
        let count = if remaining < chunk.length() {
          remaining
        } else {
          chunk.length()
        }
        @async_io.BinaryReader::drop_exactly(self, count)
        continue dropped + count
      }
    }
  } nobreak {
    len
  }
}

///|
pub async fn ReadFromProcess::read_until(
  self : ReadFromProcess,
  sep : StringView,
) -> String? {
  let pattern : &@data.Data = sep
  match
    @async_io.BinaryReader::read_until(
      self,
      pattern.binary()[:],
      include_delimiter=false,
    ) {
    None => None
    Some(bytes) => Some(@data.Data::text(bytes))
  }
}

///|
pub async fn ReadFromProcess::read_all(self : ReadFromProcess) -> &@data.Data {
  @async_io.BinaryReader::read_all(self)
}

///|
pub async fn WriteToProcess::write(
  self : WriteToProcess,
  data : &@data.Data,
) -> Unit {
  @async_io.BinaryWriter::write(self, data.binary()[:])
}

///|
pub async fn WriteToProcess::write_once(
  self : WriteToProcess,
  buf : Bytes,
  offset~ : Int32,
  len~ : Int32,
) -> Int32 {
  @async_io.BinaryWriterImpl::raw_write_impl(self, buf, offset~, len~)
}
