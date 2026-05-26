///| SHA-1 wrappers over @hash core implementation

///|
pub struct Sha1State {
  inner : @hash.Sha1State
}

///|
pub fn Sha1State::new() -> Sha1State {
  { inner: @hash.Sha1State::new() }
}

///|
pub fn Sha1State::reset(self : Sha1State) -> Unit {
  self.inner.reset()
}

///|
pub fn Sha1State::update(self : Sha1State, data : Bytes) -> Unit {
  self.inner.update(data)
}

///|
pub fn Sha1State::update_slice(
  self : Sha1State,
  data : Bytes,
  offset : Int,
  len : Int,
) -> Unit {
  self.inner.update_slice(data, offset, len)
}

///|
pub fn Sha1State::update_byte(self : Sha1State, b : Byte) -> Unit {
  self.inner.update_byte(b)
}

///|
pub fn Sha1State::update_string(self : Sha1State, s : String) -> Unit {
  self.inner.update_string(s)
}

///|
pub fn Sha1State::finish(self : Sha1State) -> ObjectId {
  ObjectId::new(self.inner.finish_raw())
}

///|
/// Compute SHA-1 hash of data prefix (first `len` bytes).
pub fn sha1_prefix(data : Bytes, len : Int) -> ObjectId {
  ObjectId::new(@hash.sha1_prefix_raw(data, len))
}

///|
/// Compute SHA-1 hash of data
pub fn sha1(data : Bytes) -> ObjectId {
  ObjectId::new(@hash.sha1_raw(data))
}

///|
/// Compute SHA-1 hash of Array prefix (first `len` bytes).
pub fn sha1_array_prefix(data : Array[Byte], len : Int) -> ObjectId {
  ObjectId::new(@hash.sha1_array_prefix_raw(data, len))
}

///|
/// Compute SHA-1 hash of data from Array
pub fn sha1_array(data : Array[Byte]) -> ObjectId {
  ObjectId::new(@hash.sha1_array_raw(data))
}
