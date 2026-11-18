///|
pub(all) enum Kind {
  Unbounded
  Blocking(Int32)
  DiscardOldest(Int32)
  DiscardLatest(Int32)
}

///|
#derive(ToJson, @debug.Debug)
pub suberror QueueAlreadyClosed

///|
pub impl Show for QueueAlreadyClosed with fn output(_self, logger) {
  logger.write_string("QueueAlreadyClosed")
}

///|
fn to_async_kind(kind : Kind) -> @async_aqueue.Kind {
  match kind {
    Unbounded => @async_aqueue.Unbounded
    Blocking(n) => @async_aqueue.Blocking(n)
    DiscardOldest(n) => @async_aqueue.DiscardOldest(n)
    DiscardLatest(n) => @async_aqueue.DiscardLatest(n)
  }
}

///|
fn classify_queue_error(err : Error) -> Error {
  if err.to_string().contains("QueueAlreadyClosed") {
    QueueAlreadyClosed
  } else {
    err
  }
}

///|
pub struct Queue[X] {
  kind : Kind
  priv inner : @async_aqueue.Queue[X]
}

///|
#alias(new, deprecated)
#as_free_fn(new, deprecated)
pub fn[X] Queue::Queue(kind~ : Kind) -> Queue[X] {
  { kind, inner: @async_aqueue.Queue(kind=to_async_kind(kind)), }
}

///|
pub fn[X] Queue::close(self : Queue[X], error? : Error, clear? : Bool) -> Unit {
  self.inner.close(error?, clear?)
}

///|
pub async fn[X] Queue::get(self : Queue[X]) -> X {
  self.inner.get() catch {
    err => raise classify_queue_error(err)
  }
}

///|
pub async fn[X] Queue::put(self : Queue[X], item : X) -> Unit {
  self.inner.put(item) catch {
    err => raise classify_queue_error(err)
  }
}

///|
pub fn[X] Queue::try_get(self : Queue[X]) -> X? raise {
  self.inner.try_get() catch {
    err => raise classify_queue_error(err)
  }
}

///|
pub fn[X] Queue::try_put(self : Queue[X], item : X) -> Bool raise {
  self.inner.try_put(item) catch {
    err => raise classify_queue_error(err)
  }
}

///|
pub extend QueueAlreadyClosed with ToJson::{to_json}

///|
pub extend QueueAlreadyClosed with @debug.Debug::{to_repr}

///|
pub extend QueueAlreadyClosed with Show::{to_string, output}
