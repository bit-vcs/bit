///| Helper functions for git-bit native CLI

///|
fn bytes_from_array(arr : Array[Byte]) -> Bytes {
  Bytes::from_array(FixedArray::makei(arr.length(), i => arr[i]))
}

///|
fn str_to_bytes(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn decode_bytes(data : Bytes) -> String {
  @string_utils.decode_bytes(data)
}

///|
fn trim_string(s : String) -> String {
  @string_utils.trim_string(s)
}

///|
async fn warn_unimplemented_arg(cmd : String, arg : String) -> Unit {
  if arg == "--" {
    return
  }
  let msg = "warning: " + cmd + ": unsupported option '" + arg + "'\n"
  @stdio.stderr.write(str_to_bytes(msg))
}

///|
async fn print_line(s : String) -> Unit {
  @stdio.stdout.write(str_to_bytes(s + "\n"))
}

///|
async fn eprint_line(s : String) -> Unit {
  @stdio.stderr.write(str_to_bytes(s + "\n"))
}

///|
async fn read_all_stdin() -> Bytes {
  let out : Array[Byte] = []
  while true {
    match @stdio.stdin.read_some(max_len=8192) {
      None => break
      Some(bytes) =>
        for b in bytes {
          out.push(b)
        }
    }
  }
  bytes_from_array(out)
}

///|
fn get_effective_remote_url(fs : OsFs, git_dir : String) -> String? {
  @bitlib.get_effective_remote_url(fs, git_dir)
}

///|
fn get_author_string() -> String {
  match @sys.get_env_var("GIT_AUTHOR_NAME") {
    Some(name) => {
      let email = @sys.get_env_var("GIT_AUTHOR_EMAIL").unwrap_or("unknown")
      name + " <" + email + ">"
    }
    None => get_identity_from_config()
  }
}

///|
fn get_identity_from_config() -> String {
  let root = get_work_root()
  let git_dir = root + "/.git"
  let config_path = git_dir + "/config"
  let content = @fs.read_file_to_string(config_path) catch { _ => "" }
  let name = if content.length() > 0 {
    @config_parse.get_config_value_from_content(
      content,
      "user.name",
      None,
      false,
    )
  } else {
    None
  }
  let email = if content.length() > 0 {
    @config_parse.get_config_value_from_content(
      content,
      "user.email",
      None,
      false,
    )
  } else {
    None
  }
  let home = @sys.get_env_var("HOME").unwrap_or("")
  let global_content = if home.length() > 0 {
    @fs.read_file_to_string(home + "/.gitconfig") catch { _ => "" }
  } else {
    ""
  }
  let name = match name {
    Some(_) => name
    None =>
      if global_content.length() > 0 {
        @config_parse.get_config_value_from_content(
          global_content,
          "user.name",
          None,
          false,
        )
      } else {
        None
      }
  }
  let email = match email {
    Some(_) => email
    None =>
      if global_content.length() > 0 {
        @config_parse.get_config_value_from_content(
          global_content,
          "user.email",
          None,
          false,
        )
      } else {
        None
      }
  }
  match (name, email) {
    (Some(n), Some(e)) => n + " <" + e + ">"
    (Some(n), None) => n + " <" + n + "@localhost>"
    (None, Some(e)) => {
      let user = @sys.get_env_var("USER").unwrap_or("Unknown")
      user + " <" + e + ">"
    }
    (None, None) =>
      match @sys.get_env_var("USER") {
        Some(u) => u + " <" + u + "@localhost>"
        None => "Unknown <unknown@localhost>"
      }
  }
}

///|
fn get_hub_signing_key() -> String? {
  match @sys.get_env_var("BIT_COLLAB_SIGN_KEY") {
    Some(value) => if value.length() > 0 { Some(value) } else { None }
    None => None
  }
}

///|
fn get_hub_require_signed() -> Bool {
  match @sys.get_env_var("BIT_COLLAB_REQUIRE_SIGNED") {
    Some(value) => {
      let normalized = value.to_lower()
      normalized == "1" || normalized == "true" || normalized == "yes"
    }
    None => false
  }
}

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
fn get_commit_timestamp() -> Int64 {
  match @sys.get_env_var("GIT_COMMITTER_DATE") {
    Some(s) =>
      match parse_git_env_timestamp(s) {
        Some(ts) => ts
        None => get_current_timestamp()
      }
    None => get_current_timestamp()
  }
}

///|
fn parse_git_env_timestamp(raw : String) -> Int64? {
  let mut token : String? = None
  for part_view in raw.split(" ") {
    let part = part_view.to_string()
    if part.length() > 0 {
      token = Some(part)
      break
    }
  }
  match token {
    Some(part) =>
      if part.has_prefix("@") {
        let numeric = String::unsafe_substring(part, start=1, end=part.length())
        let parsed = @strconv.parse_int64(numeric) catch { _ => return None }
        Some(parsed)
      } else {
        let parsed = @strconv.parse_int64(part) catch { _ => -1L }
        if parsed >= 0L {
          Some(parsed)
        } else {
          parse_iso_date_timestamp(raw)
        }
      }
    None => None
  }
}

///|
fn parse_iso_date_timestamp(raw : String) -> Int64? {
  let s = raw.trim().to_string()
  if s.length() < 16 {
    return None
  }
  if s[4] != '-' || s[7] != '-' {
    return None
  }
  let sep = s[10]
  if sep != ' ' && sep != 'T' {
    return None
  }
  let year = @strconv.parse_int64(String::unsafe_substring(s, start=0, end=4)) catch {
    _ => return None
  }
  let month = @strconv.parse_int64(String::unsafe_substring(s, start=5, end=7)) catch {
    _ => return None
  }
  let day = @strconv.parse_int64(String::unsafe_substring(s, start=8, end=10)) catch {
    _ => return None
  }
  let time_str = String::unsafe_substring(s, start=11, end=s.length())
  let mut time_end = time_str.length()
  for i in 0..<time_str.length() {
    let c = time_str[i]
    if c == ' ' || c == '+' || c == '-' {
      time_end = i
      break
    }
  }
  let time_part = String::unsafe_substring(time_str, start=0, end=time_end)
  if time_part.length() < 5 || time_part[2] != ':' {
    return None
  }
  let hour = @strconv.parse_int64(
    String::unsafe_substring(time_part, start=0, end=2),
  ) catch {
    _ => return None
  }
  let minute = @strconv.parse_int64(
    String::unsafe_substring(time_part, start=3, end=5),
  ) catch {
    _ => return None
  }
  let second = if time_part.length() >= 8 && time_part[5] == ':' {
    @strconv.parse_int64(String::unsafe_substring(time_part, start=6, end=8)) catch {
      _ => 0L
    }
  } else {
    0L
  }
  let mut ts = days_from_epoch(year, month, day) * 86400L +
    hour * 3600L +
    minute * 60L +
    second
  let after_time = String::unsafe_substring(
    s,
    start=11 + time_end,
    end=s.length(),
  )
  ts = ts - parse_iso_tz_offset_seconds(after_time)
  Some(ts)
}

///|
fn parse_iso_tz_offset_seconds(s : String) -> Int64 {
  let t = s.trim().to_string()
  if t.length() < 5 {
    return 0L
  }
  let sign : Int64 = if t[0] == '-' {
    -1L
  } else if t[0] == '+' {
    1L
  } else {
    return 0L
  }
  let (hh_str, mm_str) = if t.length() >= 6 && t[3] == ':' {
    (
      String::unsafe_substring(t, start=1, end=3),
      String::unsafe_substring(t, start=4, end=6),
    )
  } else {
    (
      String::unsafe_substring(t, start=1, end=3),
      String::unsafe_substring(t, start=3, end=5),
    )
  }
  let hh = @strconv.parse_int64(hh_str) catch { _ => return 0L }
  let mm = @strconv.parse_int64(mm_str) catch { _ => return 0L }
  sign * (hh * 3600L + mm * 60L)
}

///|
fn days_from_epoch(year : Int64, month : Int64, day : Int64) -> Int64 {
  let month_days : Array[Int64] = [
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334,
  ]
  let mut days = 365L * (year - 1970L)
  if year > 1970L {
    days = days + (year - 1969L) / 4L - (year - 1901L) / 100L +
      (year - 1601L) / 400L
  } else {
    days = days - (1970L - year) / 4L + (1970L - year) / 100L -
      (1970L - year) / 400L
  }
  days = days + month_days[(month - 1L).to_int()]
  if month > 2L {
    let is_leap = (year % 4L == 0L && year % 100L != 0L) ||
      year % 400L == 0L
    if is_leap {
      days += 1L
    }
  }
  days + day - 1L
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
  let tz_offset_seconds = parse_tz_offset(tz)
  let adjusted = ts + tz_offset_seconds.to_int64()
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
