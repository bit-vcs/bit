///| SHA-256 core implementation (hash package) using moonbitlang/x/crypto

///|
pub struct Sha256State {
  inner : @crypto.SHA256
}

///|
pub fn Sha256State::new() -> Sha256State {
  { inner: @crypto.SHA256::new() }
}

///|
pub fn Sha256State::reset(self : Sha256State) -> Unit {
  self.inner.reset()
}

///|
pub fn Sha256State::update(self : Sha256State, data : Bytes) -> Unit {
  self.inner.update(data)
}

///|
pub fn Sha256State::update_slice(
  self : Sha256State,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Unit {
  let slice = data.to_fixedarray()
  let buf = FixedArray::make(len, b'\x00')
  for i in 0..<len {
    buf[i] = slice[offset + i]
  }
  self.inner.update(buf)
}

///|
pub fn Sha256State::update_byte(self : Sha256State, b : Byte) -> Unit {
  self.inner.update(FixedArray::make(1, b))
}

///|
pub fn Sha256State::update_string(self : Sha256State, s : String) -> Unit {
  self.update(@utf8.encode(s))
}

///|
pub fn Sha256State::finish_raw(self : Sha256State) -> FixedArray[Byte] {
  self.inner.finalize()
}

///|
pub fn sha256_raw(data : Bytes) -> FixedArray[Byte] {
  sha256_prefix_raw(data, data.length())
}

///|
pub fn sha256_prefix_raw(data : Bytes, len : Int) -> FixedArray[Byte] {
  let msg_len = if len < 0 {
    0
  } else if len > data.length() {
    data.length()
  } else {
    len
  }
  let state = Sha256State::new()
  state.update_slice(data, 0, msg_len)
  state.finish_raw()
}

///|
pub fn sha256_array_prefix_raw(
  data : Array[Byte],
  len : Int,
) -> FixedArray[Byte] {
  let msg_len = if len < 0 {
    0
  } else if len > data.length() {
    data.length()
  } else {
    len
  }
  let state = Sha256State::new()
  for i in 0..<msg_len {
    state.update_byte(data[i])
  }
  state.finish_raw()
}

///|
pub fn sha256_array_raw(data : Array[Byte]) -> FixedArray[Byte] {
  sha256_array_prefix_raw(data, data.length())
}
