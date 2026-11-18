///|
test "execute basic" {
  let re = @regexp.compile("a(bc|de)f")
  let result = re.execute("xxabcf")
  inspect(result.matched(), content="true")
  inspect(result.get(0).unwrap().to_owned(), content="abcf")
  inspect(result.get(1).unwrap().to_owned(), content="bc")
}

///|
test "results" {
  let re = @regexp.compile("(\\w)+")
  let result = re.execute("abc")
  inspect(result.results().length(), content="2")
  inspect(result.get(0).unwrap().to_owned(), content="abc")
  inspect(result.get(1).unwrap().to_owned(), content="c")
}

///|
test "before and after" {
  let re = @regexp.compile("world")
  let result = re.execute("hello world")
  inspect(result.before().to_owned(), content="hello ")
  inspect(result.after().to_owned(), content="")
  let re2 = @regexp.compile("hello")
  let result2 = re2.execute("hello world")
  inspect(result2.before().to_owned(), content="")
  inspect(result2.after().to_owned(), content=" world")
}

///|
test "no match" {
  let re = @regexp.compile("xyz")
  let result = re.execute("hi there")
  inspect(result.matched(), content="false")
  inspect(result.before().to_owned(), content="hi there")
  inspect(result.after().to_owned(), content="")
  inspect(re.match_("hi there") is None, content="true")
}

///|
test "get" {
  let re = @regexp.compile(".(bc)")
  let result = re.execute("abc")
  inspect(result.get(0).unwrap().to_owned(), content="abc")
  inspect(result.get(1).unwrap().to_owned(), content="bc")
  inspect(result.get(2) is None, content="true")
}

///|
test "named groups" {
  let re = @regexp.compile("(?<word>\\w+)\\s+(?<num>\\d+)")
  inspect(re.group_by_name("word").unwrap(), content="1")
  inspect(re.group_by_name("num").unwrap(), content="2")
  inspect(re.group_by_name("missing") is None, content="true")
  let result = re.execute("hello 123")
  let groups = result.groups()
  inspect(groups.get("word").unwrap().to_owned(), content="hello")
  inspect(groups.get("num").unwrap().to_owned(), content="123")
}

///|
test "group count and names" {
  let re = @regexp.compile("(a)(b|c)")
  inspect(re.group_count(), content="3")
  let re2 = @regexp.compile("(?<first>a)(?<second>b)")
  let names = re2.group_names()
  names.sort()
  inspect(names.length(), content="2")
  inspect(names[0], content="first")
  inspect(names[1], content="second")
}

///|
test "flags" {
  let re = @regexp.compile("hello", flags="i")
  inspect(re.execute("HELLO").matched(), content="true")
  let re2 = @regexp.compile("a.b", flags="s")
  inspect(re2.execute("a\nb").matched(), content="true")
}

///|
test "match_ some" {
  let re = @regexp.compile("a(bc|de)f")
  guard! re.match_("abcfxx") is Some(result)
  inspect(result.after().to_owned(), content="xx")
}

///|
test "compile error" {
  let failed = try {
    let _ = @regexp.compile("(unclosed")
    false
  } catch {
    @regexp.RegexpError(..) => true
  }
  inspect(failed, content="true")
}
