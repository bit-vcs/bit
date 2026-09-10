///|
test "format_amz_date: the epoch itself" {
  inspect(format_amz_date(0L), content="19700101T000000Z")
}

///|
test "format_amz_date: the AWS documented example timestamp" {
  // 20130524T000000Z, the instant used by the published GET Object vector.
  inspect(format_amz_date(1369353600L), content="20130524T000000Z")
}

///|
test "format_amz_date: leap day" {
  // 2024-02-29T12:34:56Z
  inspect(format_amz_date(1709210096L), content="20240229T123456Z")
}

///|
test "format_amz_date: end of a century that is not a leap year" {
  // 1900 is not a leap year; 2000 is. 2000-02-29T23:59:59Z
  inspect(format_amz_date(951868799L), content="20000229T235959Z")
}

///|
test "format_amz_date: times before the epoch floor to the right day" {
  // 1969-12-31T23:59:59Z. Truncating division would give 19700101T...
  inspect(format_amz_date(-1L), content="19691231T235959Z")
  inspect(format_amz_date(-86400L), content="19691231T000000Z")
}

///|
test "civil_from_days round-trips against known dates" {
  fn show(days : Int64) -> String {
    let (y, m, d) = civil_from_days(days)
    "\{y}-\{m}-\{d}"
  }

  inspect(show(0L), content="1970-1-1")
  inspect(show(19723L), content="2024-1-1")
  inspect(show(-1L), content="1969-12-31")
}
