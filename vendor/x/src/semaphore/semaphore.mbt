///|
pub struct Semaphore {
  size : Int32
  priv inner : @async_semaphore.Semaphore
}

///|
#alias(new, deprecated)
pub fn Semaphore::Semaphore(size : Int32, initial_value? : Int32) -> Semaphore {
  { size, inner: @async_semaphore.Semaphore(size, initial_value?), }
}

///|
pub async fn Semaphore::acquire(self : Semaphore) -> Unit {
  self.inner.acquire()
}

///|
pub fn Semaphore::release(self : Semaphore) -> Unit {
  self.inner.release()
}

///|
pub fn Semaphore::try_acquire(self : Semaphore) -> Bool {
  self.inner.try_acquire()
}
