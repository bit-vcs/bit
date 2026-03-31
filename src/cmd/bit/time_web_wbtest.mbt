///| Time tests for JS and WASM targets.

///|
fn time_web_now_sec() -> Int64 {
  (@env.now() / 1000UL).reinterpret_as_int64()
}

///|
fn time_web_abs_diff(left : Int64, right : Int64) -> Int64 {
  if left >= right {
    left - right
  } else {
    right - left
  }
}

///|
test "time web: current timestamp tracks env.now" {
  let expected = time_web_now_sec()
  let got = get_current_timestamp()
  assert_true(got > 0L)
  assert_true(time_web_abs_diff(got, expected) <= 1L)
}
