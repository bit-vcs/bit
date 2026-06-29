///|
test "date_is_leap_year" {
  assert_true(@bit_date.date_is_leap_year(2000))
  assert_true(@bit_date.date_is_leap_year(2024))
  assert_false(@bit_date.date_is_leap_year(1900))
  assert_false(@bit_date.date_is_leap_year(2023))
}

///|
test "days_since_epoch known dates" {
  // 1970-01-01 = day 0
  @test.assert_eq(@bit_date.days_since_epoch(1970, 1, 1), 0)
  // 1970-01-02 = day 1
  @test.assert_eq(@bit_date.days_since_epoch(1970, 1, 2), 1)
  // 2000-01-01 = 10957 days
  @test.assert_eq(@bit_date.days_since_epoch(2000, 1, 1), 10957)
}

///|
test "month_name_to_number" {
  @test.assert_eq(@bit_date.month_name_to_number("jan"), Some(1))
  @test.assert_eq(@bit_date.month_name_to_number("January"), Some(1))
  @test.assert_eq(@bit_date.month_name_to_number("dec"), Some(12))
  @test.assert_eq(@bit_date.month_name_to_number("December"), Some(12))
  @test.assert_eq(@bit_date.month_name_to_number("may"), Some(5))
  @test.assert_eq(@bit_date.month_name_to_number("xyz"), None)
  @test.assert_eq(@bit_date.month_name_to_number(""), None)
}

///|
test "parse_approxidate ISO 8601" {
  // 2024-01-15T00:00:00 => days_since_epoch(2024,1,15) * 86400
  let result = @bit_date.parse_approxidate("2024-01-15T00:00:00", 0L)
  assert_true(result is Some(_))
  let ts = result.unwrap()
  let expected = @bit_date.days_since_epoch(2024, 1, 15).to_int64() * 86400L
  @test.assert_eq(ts, expected)
}

///|
test "parse_approxidate relative" {
  let now = 1000000L
  let result = @bit_date.parse_approxidate("3 days ago", now)
  @test.assert_eq(result, Some(now - 3L * 86400L))
  let yesterday = @bit_date.parse_approxidate("yesterday", now)
  @test.assert_eq(yesterday, Some(now - 86400L))
  let now_result = @bit_date.parse_approxidate("now", now)
  @test.assert_eq(now_result, Some(now))
}

///|
test "parse_approxidate human readable" {
  let result = @bit_date.parse_approxidate("Jan 1 2000", 0L)
  assert_true(result is Some(_))
  let expected = @bit_date.days_since_epoch(2000, 1, 1).to_int64() * 86400L
  @test.assert_eq(result.unwrap(), expected)
}

///|
test "parse_approxidate_epoch" {
  @test.assert_eq(@bit_date.parse_approxidate_epoch("@1234567890"), Some(1234567890L))
  @test.assert_eq(
    @bit_date.parse_approxidate_epoch("@1234567890 +0000"),
    Some(1234567890L),
  )
  @test.assert_eq(
    @bit_date.parse_approxidate_epoch("@1117150200 -0500"),
    Some(1117150200L),
  )
  // Not the epoch form.
  @test.assert_eq(@bit_date.parse_approxidate_epoch("1234567890"), None)
  @test.assert_eq(@bit_date.parse_approxidate_epoch("@"), None)
  @test.assert_eq(@bit_date.parse_approxidate_epoch("@12abc"), None)
  // parse_approxidate dispatches to the epoch form.
  @test.assert_eq(@bit_date.parse_approxidate("@1234567890", 0L), Some(1234567890L))
}
