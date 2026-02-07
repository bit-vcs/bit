///|
extern "C" fn mcp_read_message_ffi() -> String = "mcp_read_message_ffi"

///|
#borrow(msg)
extern "C" fn mcp_write_message_ffi(msg : Bytes) -> Unit = "mcp_write_message_ffi"

///|
#borrow(msg)
extern "C" fn mcp_log_ffi(msg : Bytes) -> Unit = "mcp_log_ffi"

///|
fn string_to_utf8(s : String) -> Bytes {
  let buf : Array[Byte] = []
  for ch in s {
    let cp = ch.to_uint()
    if cp < 0x80U {
      buf.push(cp.to_byte())
    } else if cp < 0x800U {
      buf.push((0xC0U | (cp >> 6)).to_byte())
      buf.push((0x80U | (cp & 0x3FU)).to_byte())
    } else if cp < 0x10000U {
      buf.push((0xE0U | (cp >> 12)).to_byte())
      buf.push((0x80U | ((cp >> 6) & 0x3FU)).to_byte())
      buf.push((0x80U | (cp & 0x3FU)).to_byte())
    } else {
      buf.push((0xF0U | (cp >> 18)).to_byte())
      buf.push((0x80U | ((cp >> 12) & 0x3FU)).to_byte())
      buf.push((0x80U | ((cp >> 6) & 0x3FU)).to_byte())
      buf.push((0x80U | (cp & 0x3FU)).to_byte())
    }
  }
  buf.push(b'\x00')
  Bytes::from_array(buf)
}

///|
fn read_message() -> String {
  mcp_read_message_ffi()
}

///|
fn write_message(s : String) -> Unit {
  mcp_write_message_ffi(string_to_utf8(s))
}

///|
fn log(s : String) -> Unit {
  mcp_log_ffi(string_to_utf8(s))
}
