///|
/// Text or binary payload accepted by the compatibility APIs.
/// Stream operations use `moonbitlang/core/async/io` binary traits directly.
pub(open) trait Data {
  fn text(Self) -> String raise
  fn binary(Self) -> Bytes
  fn json(Self) -> Json raise = _
}

///|
pub impl Data for String with fn text(self) {
  self
}

///|
pub impl Data for String with fn binary(self) {
  @utf8.encode(self)
}

///|
pub impl Data for Bytes with fn text(self) {
  @utf8.decode(self)
}

///|
pub impl Data for Bytes with fn binary(self) {
  self
}

///|
pub impl Data for BytesView with fn text(self) {
  @utf8.decode(self)
}

///|
pub impl Data for BytesView with fn binary(self) {
  self.to_owned()
}

///|
impl Data with fn json(self) {
  @json.parse(self.text())
}

///|
pub impl Data for StringView with fn text(self) {
  self.to_owned()
}

///|
pub impl Data for StringView with fn binary(self) {
  @utf8.encode(self)
}

///|
pub impl Data for Json with fn text(self) {
  self.stringify()
}

///|
pub impl Data for Json with fn binary(self) {
  @utf8.encode(self.stringify())
}

///|
pub impl Data for Json with fn json(self) {
  self
}
