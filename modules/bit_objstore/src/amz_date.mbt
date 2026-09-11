///|
/// `x-amz-date` formatting.
///
/// Kept here, pure and target-agnostic, so the format is testable and only
/// the clock read itself has to be provided per target.

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad4(n : Int) -> String {
  if n < 10 {
    "000" + n.to_string()
  } else if n < 100 {
    "00" + n.to_string()
  } else if n < 1000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
/// Civil date from days since the Unix epoch (Howard Hinnant's algorithm).
///
/// Valid for the whole proleptic Gregorian range, so a clock that is badly
/// wrong produces a wrong date rather than nonsense.
pub fn civil_from_days(days : Int64) -> (Int, Int, Int) {
  let z = days + 719468L
  let era = (if z >= 0L { z } else { z - 146096L }) / 146097L
  let doe = z - era * 146097L
  let yoe = (doe - doe / 1460L + doe / 36524L - doe / 146096L) / 365L
  let y = yoe + era * 400L
  let doy = doe - (365L * yoe + yoe / 4L - yoe / 100L)
  let mp = (5L * doy + 2L) / 153L
  let d = doy - (153L * mp + 2L) / 5L + 1L
  let m = mp + (if mp < 10L { 3L } else { -9L })
  let year = if m <= 2L { y + 1L } else { y }
  (year.to_int(), m.to_int(), d.to_int())
}

///|
/// Format Unix epoch seconds as SigV4's `YYYYMMDDTHHMMSSZ`, in UTC.
pub fn format_amz_date(epoch_seconds : Int64) -> String {
  // Floor division, so times before 1970 do not round toward zero and land
  // on the wrong day.
  let mut days = epoch_seconds / 86400L
  let mut rem = epoch_seconds % 86400L
  if rem < 0L {
    rem += 86400L
    days -= 1L
  }
  let (year, month, day) = civil_from_days(days)
  let hour = (rem / 3600L).to_int()
  let minute = ((rem % 3600L) / 60L).to_int()
  let second = (rem % 60L).to_int()
  "\{pad4(year)}\{pad2(month)}\{pad2(day)}T\{pad2(hour)}\{pad2(minute)}\{pad2(second)}Z"
}
