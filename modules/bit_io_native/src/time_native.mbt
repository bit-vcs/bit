///| Wall clock for object-store request signing (native only).

///|
extern "c" fn bit_objstore_current_time_ffi() -> Int64 = "bit_objstore_current_time"

///|
/// Current time as SigV4's `YYYYMMDDTHHMMSSZ`.
///
/// A signed request is rejected when its timestamp drifts more than a few
/// minutes from the server's, so this must be a real clock, not a counter.
pub fn amz_date_now() -> String {
  @objstore.format_amz_date(bit_objstore_current_time_ffi())
}
