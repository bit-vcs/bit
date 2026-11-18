///|
test "signal to_int" {
  assert_true(@signal.SIGINT.to_int() > 0)
  assert_true(@signal.SIGTERM.to_int() > 0)
}

///|
test "set global cancellation signals accepts list" {
  @signal.set_global_cancellation_signals([@signal.SIGINT, @signal.SIGTERM])
}
