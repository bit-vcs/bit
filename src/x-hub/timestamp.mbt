///| ISO 8601 timestamp parser and formatter

///|
/// Check if a year is a leap year
fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
/// Days in each month for a given year
fn days_in_month(month : Int, year : Int) -> Int {
  match month {
    1 => 31
    2 => if is_leap_year(year) { 29 } else { 28 }
    3 => 31
    4 => 30
    5 => 31
    6 => 30
    7 => 31
    8 => 31
    9 => 30
    10 => 31
    11 => 30
    12 => 31
    _ => 30
  }
}

///|
/// Days in a year
fn days_in_year(year : Int) -> Int {
  if is_leap_year(year) {
    366
  } else {
    365
  }
}

///|
/// Parse a substring as an integer
fn parse_int_sub(s : String, start : Int, end : Int) -> Int {
  let sub = String::unsafe_substring(s, start~, end~)
  parse_int(sub)
}

///|
/// Parse ISO 8601 timestamp string to Unix seconds.
/// Supports "YYYY-MM-DDThh:mm:ssZ" and "YYYY-MM-DDThh:mm:ss+00:00" formats.
/// Returns 0 for empty or unparseable strings.
pub fn parse_iso8601_to_unix(iso_str : String) -> Int64 {
  if iso_str.length() < 19 {
    return 0L
  }
  let year = parse_int_sub(iso_str, 0, 4)
  let month = parse_int_sub(iso_str, 5, 7)
  let day = parse_int_sub(iso_str, 8, 10)
  let hour = parse_int_sub(iso_str, 11, 13)
  let minute = parse_int_sub(iso_str, 14, 16)
  let second = parse_int_sub(iso_str, 17, 19)
  // Count days from 1970-01-01 to the given date
  let mut days = 0L
  // Add days for complete years
  for y = 1970; y < year; y = y + 1 {
    days = days + days_in_year(y).to_int64()
  }
  // Add days for complete months in the target year
  for m = 1; m < month; m = m + 1 {
    days = days + days_in_month(m, year).to_int64()
  }
  // Add remaining days (day is 1-based)
  days = days + (day - 1).to_int64()
  days * 86400L +
  hour.to_int64() * 3600L +
  minute.to_int64() * 60L +
  second.to_int64()
}

///|
/// Convert Unix seconds to ISO 8601 string in UTC ("YYYY-MM-DDThh:mm:ssZ").
pub fn unix_to_iso8601(unix : Int64) -> String {
  let mut remaining = unix
  let second = (remaining % 60L).to_int()
  remaining = remaining / 60L
  let minute = (remaining % 60L).to_int()
  remaining = remaining / 60L
  let hour = (remaining % 24L).to_int()
  let mut days = (remaining / 24L).to_int()
  // Compute year
  let mut year = 1970
  while true {
    let diy = days_in_year(year)
    if days < diy {
      break
    }
    days = days - diy
    year = year + 1
  }
  // Compute month
  let mut month = 1
  while month <= 12 {
    let dim = days_in_month(month, year)
    if days < dim {
      break
    }
    days = days - dim
    month = month + 1
  }
  let day = days + 1
  // Format with zero-padding
  let buf = StringBuilder::new()
  buf.write_string(pad4(year))
  buf.write_string("-")
  buf.write_string(pad2(month))
  buf.write_string("-")
  buf.write_string(pad2(day))
  buf.write_string("T")
  buf.write_string(pad2(hour))
  buf.write_string(":")
  buf.write_string(pad2(minute))
  buf.write_string(":")
  buf.write_string(pad2(second))
  buf.write_string("Z")
  buf.to_string()
}

///|
/// Zero-pad an integer to 2 digits
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
/// Zero-pad an integer to 4 digits
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
