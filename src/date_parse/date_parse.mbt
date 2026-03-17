///|
/// Parse digits from a character array between start (inclusive) and end (exclusive).
pub fn parse_date_digits(chars : Array[Char], start : Int, end : Int) -> Int {
  let mut result = 0
  for i in start..<end {
    if i < chars.length() {
      let c = chars[i]
      if c >= '0' && c <= '9' {
        result = result * 10 + (c.to_int() - '0'.to_int())
      }
    }
  }
  result
}

///|
/// Calculate the number of days since the Unix epoch (1970-01-01).
pub fn days_since_epoch(year : Int, month : Int, day : Int) -> Int {
  let mut days = 0
  for y in 1970..<year {
    days += if date_is_leap_year(y) { 366 } else { 365 }
  }
  let month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  for m in 1..<month {
    days += month_days[m - 1]
    if m == 2 && date_is_leap_year(year) {
      days += 1
    }
  }
  days + day - 1
}

///|
/// Check if a year is a leap year.
pub fn date_is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
/// Parse a leading integer from a string, stopping at the first non-digit.
pub fn parse_int_from_string(s : String) -> Int {
  let mut result = 0
  let mut found = false
  for c in s {
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
      found = true
    } else {
      break
    }
  }
  if found {
    result
  } else {
    0
  }
}

///|
/// Convert a month name (e.g. "jan", "february") to its number (1-12).
pub fn month_name_to_number(name : String) -> Int? {
  let lower = name.to_lower()
  if lower == "jan" || lower == "january" {
    Some(1)
  } else if lower == "feb" || lower == "february" {
    Some(2)
  } else if lower == "mar" || lower == "march" {
    Some(3)
  } else if lower == "apr" || lower == "april" {
    Some(4)
  } else if lower == "may" {
    Some(5)
  } else if lower == "jun" || lower == "june" {
    Some(6)
  } else if lower == "jul" || lower == "july" {
    Some(7)
  } else if lower == "aug" || lower == "august" {
    Some(8)
  } else if lower == "sep" || lower == "september" {
    Some(9)
  } else if lower == "oct" || lower == "october" {
    Some(10)
  } else if lower == "nov" || lower == "november" {
    Some(11)
  } else if lower == "dec" || lower == "december" {
    Some(12)
  } else {
    None
  }
}

///|
/// Parse an ISO 8601 date/time string (e.g. "2024-01-15T10:30:00").
/// Returns 0 if the string is too short.
pub fn parse_approxidate_iso8601(s : String) -> Int64 {
  let chars = s.to_array()
  if chars.length() < 10 {
    return 0L
  }
  let year = parse_date_digits(chars, 0, 4)
  let month = parse_date_digits(chars, 5, 7)
  let day = parse_date_digits(chars, 8, 10)
  let mut hour = 0
  let mut minute = 0
  let mut second = 0
  if chars.length() >= 19 {
    hour = parse_date_digits(chars, 11, 13)
    minute = parse_date_digits(chars, 14, 16)
    second = parse_date_digits(chars, 17, 19)
  }
  let days = days_since_epoch(year, month, day)
  days.to_int64() * 86400L +
  hour.to_int64() * 3600L +
  minute.to_int64() * 60L +
  second.to_int64()
}

///|
/// Parse a YYYY-MM-DD date string, optionally with time (YYYY-MM-DD HH:MM:SS or YYYY-MM-DDTHH:MM:SS).
pub fn parse_approxidate_iso_date(s : String) -> Int64? {
  let chars = s.to_array()
  if chars.length() < 10 {
    return None
  }
  guard chars[4] == '-' && chars[7] == '-' else { return None }
  let year = parse_date_digits(chars, 0, 4)
  let month = parse_date_digits(chars, 5, 7)
  let day = parse_date_digits(chars, 8, 10)
  if year < 1970 || month < 1 || month > 12 || day < 1 || day > 31 {
    return None
  }
  let mut hour = 0
  let mut minute = 0
  let mut second = 0
  if chars.length() >= 19 && (chars[10] == ' ' || chars[10] == 'T') {
    hour = parse_date_digits(chars, 11, 13)
    minute = parse_date_digits(chars, 14, 16)
    second = parse_date_digits(chars, 17, 19)
  }
  let days = days_since_epoch(year, month, day)
  Some(
    days.to_int64() * 86400L +
    hour.to_int64() * 3600L +
    minute.to_int64() * 60L +
    second.to_int64(),
  )
}

///|
/// Parse a human-readable date string like "Jan 15 2024" or "January 15 2024 10:30:00".
pub fn parse_approxidate_human(s : String) -> Int64? {
  let parts : Array[String] = []
  for p in s.split(" ") {
    let ps = p.to_string()
    if ps.length() > 0 {
      parts.push(ps)
    }
  }
  if parts.length() < 3 {
    return None
  }
  match month_name_to_number(parts[0]) {
    Some(month) => {
      let day = parse_int_from_string(parts[1])
      let year = parse_int_from_string(parts[2])
      if day <= 0 || year < 1970 {
        return None
      }
      let mut hour = 0
      let mut minute = 0
      let mut second = 0
      if parts.length() >= 4 {
        let time_parts : Array[String] = []
        for tp in parts[3].split(":") {
          time_parts.push(tp.to_string())
        }
        if time_parts.length() >= 1 {
          hour = parse_int_from_string(time_parts[0])
        }
        if time_parts.length() >= 2 {
          minute = parse_int_from_string(time_parts[1])
        }
        if time_parts.length() >= 3 {
          second = parse_int_from_string(time_parts[2])
        }
      }
      let days = days_since_epoch(year, month, day)
      Some(
        days.to_int64() * 86400L +
        hour.to_int64() * 3600L +
        minute.to_int64() * 60L +
        second.to_int64(),
      )
    }
    None => None
  }
}

///|
/// Parse a relative date string like "2 weeks ago", "yesterday", "now".
/// Takes the current timestamp as a parameter for purity.
pub fn parse_approxidate_relative(s : String, now : Int64) -> Int64? {
  let lower = s.to_lower()
  if lower == "now" {
    return Some(now)
  }
  if lower == "yesterday" {
    return Some(now - 86400L)
  }
  // Split by spaces and dots (git treats both as separators)
  let normalized = lower.replace_all(old=".", new=" ")
  let parts : Array[String] = []
  for p in normalized.split(" ") {
    let ps = p.to_string()
    if ps.length() > 0 {
      parts.push(ps)
    }
  }
  if parts.length() >= 3 && parts[parts.length() - 1] == "ago" {
    let n = parse_int_from_string(parts[0])
    if n <= 0 {
      return None
    }
    let unit = parts[1]
    let seconds_per_unit : Int64 = if unit == "second" ||
      unit == "seconds" ||
      unit == "sec" ||
      unit == "secs" {
      1L
    } else if unit == "minute" ||
      unit == "minutes" ||
      unit == "min" ||
      unit == "mins" {
      60L
    } else if unit == "hour" || unit == "hours" {
      3600L
    } else if unit == "day" || unit == "days" {
      86400L
    } else if unit == "week" || unit == "weeks" {
      604800L
    } else if unit == "month" || unit == "months" {
      2592000L
    } else if unit == "year" || unit == "years" {
      31536000L
    } else {
      return None
    }
    return Some(now - n.to_int64() * seconds_per_unit)
  }
  None
}

///|
/// Parse a date string trying multiple formats: ISO 8601, relative, human-readable, YYYY-MM-DD.
/// Takes the current timestamp for relative date resolution.
pub fn parse_approxidate(date_str : String, now : Int64) -> Int64? {
  let s = date_str
  if s.find("T") is Some(_) {
    let ts = parse_approxidate_iso8601(s)
    if ts > 0L {
      return Some(ts)
    }
  }
  match parse_approxidate_relative(s, now) {
    Some(ts) => return Some(ts)
    None => ()
  }
  match parse_approxidate_human(s) {
    Some(ts) => return Some(ts)
    None => ()
  }
  match parse_approxidate_iso_date(s) {
    Some(ts) => return Some(ts)
    None => ()
  }
  None
}
