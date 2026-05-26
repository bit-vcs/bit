///| Native time implementation using C FFI

///|
extern "c" fn bit_current_time_ffi() -> Int64 = "bit_current_time"

///|
pub fn get_current_timestamp() -> Int64 {
  bit_current_time_ffi()
}
