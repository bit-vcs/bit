///|
pub(all) enum CancellationKind {
  Graceful(Int32, @signal.Signal?)
  Hard
}

///|
pub(all) struct CancellationHandler {
  kind : CancellationKind
}

///|
pub fn graceful_cancel(
  timeout~ : Int32,
  signal? : @signal.Signal,
) -> CancellationHandler {
  { kind: Graceful(timeout, signal), }
}

///|
pub fn hard_cancel() -> CancellationHandler {
  { kind: Hard, }
}
