// Timestamp and calendar formatting for `bit log`. These are pure,
// dependency-free helpers (epoch<->calendar conversion, timezone offset
// parsing, and the git date output modes) extracted from log.mbt. The
// `format_date_by_mode` dispatcher in log.mbt selects among them.

///|
fn format_timestamp_default(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let dow = day_of_week(year, month, day)
  let dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let dn = dow_names[dow]
  let mn = month_names[month - 1]
  "\{dn} \{mn} \{day} \{pad2(hour)}:\{pad2(minute)}:\{pad2(second)} \{year} \{tz}"
}

///|
fn format_timestamp_default_notz(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let dow = day_of_week(year, month, day)
  let dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let dn = dow_names[dow]
  let mn = month_names[month - 1]
  "\{dn} \{mn} \{day} \{pad2(hour)}:\{pad2(minute)}:\{pad2(second)} \{year}"
}

///|
fn format_timestamp_short(ts : Int64, tz : String) -> String {
  let (year, month, day, _, _, _) = epoch_to_calendar(ts, tz)
  "\{year}-\{pad2(month)}-\{pad2(day)}"
}

///|
fn format_timestamp_iso_strict(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let tz_formatted = if tz.length() >= 5 {
    String::unsafe_substring(tz, start=0, end=3) +
    ":" +
    String::unsafe_substring(tz, start=3, end=5)
  } else {
    tz
  }
  "\{year}-\{pad2(month)}-\{pad2(day)}T\{pad2(hour)}:\{pad2(minute)}:\{pad2(second)}\{tz_formatted}"
}

///|
fn format_timestamp_iso(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let y = year.to_string()
  let mo = pad2(month)
  let d = pad2(day)
  let h = pad2(hour)
  let mi = pad2(minute)
  let s = pad2(second)
  "\{y}-\{mo}-\{d} \{h}:\{mi}:\{s} \{tz}"
}

///|
fn format_timestamp_rfc2822(ts : Int64, tz : String) -> String {
  let (year, month, day, hour, minute, second) = epoch_to_calendar(ts, tz)
  let dow = day_of_week(year, month, day)
  let dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  let month_names = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
    "Dec",
  ]
  let dn = dow_names[dow]
  let mn = month_names[month - 1]
  let d = day.to_string()
  let y = year.to_string()
  let h = pad2(hour)
  let mi = pad2(minute)
  let s = pad2(second)
  "\{dn}, \{d} \{mn} \{y} \{h}:\{mi}:\{s} \{tz}"
}

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn epoch_to_calendar(ts : Int64, tz : String) -> (Int, Int, Int, Int, Int, Int) {
  // Parse timezone offset
  let tz_offset_seconds = parse_tz_offset(tz)
  let adjusted = ts + tz_offset_seconds.to_int64()
  // Convert epoch seconds to y/m/d h:m:s
  let mut days = (adjusted / 86400L).to_int()
  let mut remaining = (adjusted % 86400L).to_int()
  if remaining < 0 {
    days -= 1
    remaining += 86400
  }
  let hour = remaining / 3600
  remaining = remaining % 3600
  let minute = remaining / 60
  let second = remaining % 60
  // Days since 1970-01-01
  let (year, month, day) = log_days_to_date(days)
  (year, month, day, hour, minute, second)
}

///|
fn parse_tz_offset(tz : String) -> Int {
  if tz.length() < 5 {
    return 0
  }
  let chars = tz.to_array()
  let sign = if chars[0] == '-' { -1 } else { 1 }
  let h = (chars[1].to_int() - '0'.to_int()) * 10 +
    (chars[2].to_int() - '0'.to_int())
  let m = (chars[3].to_int() - '0'.to_int()) * 10 +
    (chars[4].to_int() - '0'.to_int())
  sign * (h * 3600 + m * 60)
}

///|
fn log_days_to_date(days_since_epoch : Int) -> (Int, Int, Int) {
  // Algorithm from http://howardhinnant.github.io/date_algorithms.html
  let z = days_since_epoch + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = mp + (if mp < 10 { 3 } else { -9 })
  let year = y + (if m <= 2 { 1 } else { 0 })
  (year, m, d)
}

///|
fn day_of_week(year : Int, month : Int, day : Int) -> Int {
  // Tomohiko Sakamoto's algorithm (0=Sunday)
  let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let y = if month < 3 { year - 1 } else { year }
  (y + y / 4 - y / 100 + y / 400 + t[month - 1] + day) % 7
}
