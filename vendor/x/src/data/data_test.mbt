///|
test "text and binary payloads preserve UTF-8" {
  let text : &@data.Data = "MoonBit 🌙"
  let binary : &@data.Data = b"MoonBit \xf0\x9f\x8c\x99"
  assert_eq(text.binary(), binary.binary())
  assert_eq(binary.text(), text.text())
}

///|
test "invalid UTF-8 is preserved as binary and rejected as text" {
  let data : &@data.Data = b"\xff\x00"
  assert_eq(data.binary(), b"\xff\x00")
  let failed = try {
    ignore(data.text())
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "JSON and string views remain compatible payloads" {
  let input = "_{\"ok\":true}_"
  let view : &@data.Data = input[1:12]
  let value : Json = { "ok": true, "value": 3 }
  let json : &@data.Data = value
  assert_eq(view.text(), "{\"ok\":true}")
  assert_eq(view.json(), { "ok": true })
  assert_eq(json.json(), value)
}
