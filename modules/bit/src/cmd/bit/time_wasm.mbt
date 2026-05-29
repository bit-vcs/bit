///| WASM time implementation.

///|
pub fn get_current_timestamp() -> Int64 {
  (@env.now() / 1000UL).reinterpret_as_int64()
}
