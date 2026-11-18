///|
fn to_async_signal(signal : Signal) -> @async_signal.Signal {
  match signal {
    SIGINT => @async_signal.SIGINT
    SIGTERM => @async_signal.SIGTERM
    SIGHUP => @async_signal.SIGHUP
    SIGBREAK => @async_signal.SIGBREAK
  }
}

///|
pub fn Signal::to_int(self : Signal) -> Int32 {
  to_async_signal(self).to_int()
}

///|
pub fn set_global_cancellation_signals(signals : ReadOnlyArray[Signal]) -> Unit {
  @async_signal.set_global_cancellation_signals(signals.map(to_async_signal))
}
