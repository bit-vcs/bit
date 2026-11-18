///|
pub fn Signal::to_int(self : Signal) -> Int32 {
  match self {
    SIGINT => 2
    SIGTERM => 15
    SIGHUP => 1
    SIGBREAK => 21
  }
}

///|
pub fn set_global_cancellation_signals(signals : ReadOnlyArray[Signal]) -> Unit {
  ignore(signals)
}
