///| SHA-256 wrappers over @hash core implementation

///|
pub struct Sha256State {
  inner : @hash.Sha256State
}

///|
pub fn Sha256State::new() -> Sha256State {
  { inner: @hash.Sha256State::new() }
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
  self.inner.update_slice(data, offset, len)
}

///|
pub fn Sha256State::update_byte(self : Sha256State, b : Byte) -> Unit {
  self.inner.update_byte(b)
}

///|
pub fn Sha256State::update_string(self : Sha256State, s : String) -> Unit {
  self.inner.update_string(s)
}

///|
pub fn Sha256State::finish(self : Sha256State) -> ObjectId {
  ObjectId::new(self.inner.finish_raw())
}

///|
pub fn sha256(data : Bytes) -> ObjectId {
  ObjectId::new(@hash.sha256_raw(data))
}

///|
pub fn sha256_prefix(data : Bytes, len : Int) -> ObjectId {
  ObjectId::new(@hash.sha256_prefix_raw(data, len))
}

///|
pub fn sha256_array_prefix(data : Array[Byte], len : Int) -> ObjectId {
  ObjectId::new(@hash.sha256_array_prefix_raw(data, len))
}

///|
pub fn sha256_array(data : Array[Byte]) -> ObjectId {
  ObjectId::new(@hash.sha256_array_raw(data))
}
