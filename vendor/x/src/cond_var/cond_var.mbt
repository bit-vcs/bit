///|
pub struct Cond {
  priv inner : @async_cond.Cond
}

///|
#alias(new, deprecated)
pub fn Cond::Cond() -> Cond {
  { inner: @async_cond.Cond(), }
}

///|
pub async fn Cond::wait(self : Cond) -> Unit {
  self.inner.wait()
}

///|
pub fn Cond::signal(self : Cond) -> Unit {
  self.inner.signal()
}

///|
pub fn Cond::broadcast(self : Cond) -> Unit {
  self.inner.broadcast()
}
