///|
test "roundtrip compact" {
  let src = "{\"name\":\"moon\",\"values\":[1,2,3],\"ok\":true,\"nothing\":null}"
  inspect(@json.stringify(@json.parse(src)), content=src)
}

///|
test "parse object" {
  let j = @json.parse("{\"name\":\"moon\",\"n\":42}")
  guard! j is Object(obj)
  guard! obj.get("name") is Some(String(s))
  inspect(s, content="moon")
  guard! obj.get("n") is Some(Number(n, ..))
  inspect(n.to_int(), content="42")
}

///|
test "nested access" {
  guard! @json.parse("{\"a\":{\"b\":[10]}}") is Object(o)
  guard! o.get("a") is Some(Object(inner))
  guard! inner.get("b") is Some(Array(arr))
  guard! arr[0] is Number(n, ..)
  inspect(n.to_int(), content="10")
}

///|
test "stringify scalars" {
  inspect(
    @json.stringify(@upstream.ToJson::to_json("hi")),
    content=(
      #|"hi"
    ),
  )
  inspect(@json.stringify(@upstream.ToJson::to_json(3.5)), content="3.5")
  inspect(@json.stringify(@upstream.ToJson::to_json(true)), content="true")
  inspect(@json.stringify(Json::null()), content="null")
}

///|
test "escape slash" {
  let j = @upstream.ToJson::to_json("a/b")
  inspect(
    @json.stringify(j),
    content=(
      #|"a/b"
    ),
  )
  inspect(
    @json.stringify(j, escape_slash=true),
    content=(
      #|"a\/b"
    ),
  )
}

///|
test "stringify indent" {
  let j = @json.parse("{\"a\":1}")
  inspect(
    @json.stringify(j, indent=2),
    content=(
      #|{
      #|  "a": 1
      #|}
    ),
  )
}
