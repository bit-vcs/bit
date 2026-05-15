///|
test "date_is_leap_year" {
  assert_true(@date_parse.date_is_leap_year(2000))
  assert_true(@date_parse.date_is_leap_year(2024))
  assert_false(@date_parse.date_is_leap_year(1900))
  assert_false(@date_parse.date_is_leap_year(2023))
}

///|
test "days_since_epoch known dates" {
  // 1970-01-01 = day 0
  assert_eq(@date_parse.days_since_epoch(1970, 1, 1), 0)
  // 1970-01-02 = day 1
  assert_eq(@date_parse.days_since_epoch(1970, 1, 2), 1)
  // 2000-01-01 = 10957 days
  assert_eq(@date_parse.days_since_epoch(2000, 1, 1), 10957)
}

///|
test "month_name_to_number" {
  assert_eq(@date_parse.month_name_to_number("jan"), Some(1))
  assert_eq(@date_parse.month_name_to_number("January"), Some(1))
  assert_eq(@date_parse.month_name_to_number("dec"), Some(12))
  assert_eq(@date_parse.month_name_to_number("December"), Some(12))
  assert_eq(@date_parse.month_name_to_number("may"), Some(5))
  assert_eq(@date_parse.month_name_to_number("xyz"), None)
  assert_eq(@date_parse.month_name_to_number(""), None)
}

///|
test "parse_approxidate ISO 8601" {
  // 2024-01-15T00:00:00 => days_since_epoch(2024,1,15) * 86400
  let result = @date_parse.parse_approxidate("2024-01-15T00:00:00", 0L)
  assert_true(result is Some(_))
  let ts = result.unwrap()
  let expected = @date_parse.days_since_epoch(2024, 1, 15).to_int64() * 86400L
  assert_eq(ts, expected)
}

///|
test "parse_approxidate relative" {
  let now = 1000000L
  let result = @date_parse.parse_approxidate("3 days ago", now)
  assert_eq(result, Some(now - 3L * 86400L))
  let yesterday = @date_parse.parse_approxidate("yesterday", now)
  assert_eq(yesterday, Some(now - 86400L))
  let now_result = @date_parse.parse_approxidate("now", now)
  assert_eq(now_result, Some(now))
}

///|
test "parse_approxidate human readable" {
  let result = @date_parse.parse_approxidate("Jan 1 2000", 0L)
  assert_true(result is Some(_))
  let expected = @date_parse.days_since_epoch(2000, 1, 1).to_int64() * 86400L
  assert_eq(result.unwrap(), expected)
}
