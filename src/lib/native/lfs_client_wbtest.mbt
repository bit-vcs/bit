///|
test "lfs_build_batch_request_json: single object" {
  let ptr = @bitlib.parse_lfs_pointer(
    b"version https://git-lfs.github.com/spec/v1\noid sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd\nsize 9876\n",
  ).unwrap()
  let objects : Array[@bitlib.LfsPointer] = [ptr]
  let json_str = lfs_build_batch_request_json(objects)
  let parsed = @json.parse(json_str)
  guard parsed is Json::Object(obj) else { assert_true(false); return }
  assert_eq(obj.get("operation"), Some(Json::string("download")))
  guard obj.get("objects") is Some(Json::Array(arr)) else {
    assert_true(false)
    return
  }
  assert_eq(arr.length(), 1)
  guard arr[0] is Json::Object(o) else { assert_true(false); return }
  assert_eq(
    o.get("oid"),
    Some(
      Json::string(
        "abc123def456abc123def456abc123def456abc123def456abc123def456abcd",
      ),
    ),
  )
  assert_eq(o.get("size"), Some(Json::number(9876.0)))
}

///|
test "lfs_parse_batch_response: success with download action" {
  let json_str =
    #|{
    #|  "transfer": "basic",
    #|  "objects": [
    #|    {
    #|      "oid": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    #|      "size": 5000,
    #|      "actions": {
    #|        "download": {
    #|          "href": "https://example.com/download/obj1",
    #|          "header": {
    #|            "Authorization": "Bearer token123"
    #|          }
    #|        }
    #|      }
    #|    }
    #|  ]
    #|}
  let (actions, errors) = lfs_parse_batch_response(json_str)
  assert_eq(actions.length(), 1)
  assert_eq(errors.length(), 0)
  assert_eq(actions[0].oid, "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
  assert_eq(actions[0].size, 5000L)
  assert_eq(actions[0].href, "https://example.com/download/obj1")
  assert_eq(actions[0].headers.get("Authorization"), Some("Bearer token123"))
}

///|
test "lfs_parse_batch_response: object with error" {
  let json_str =
    #|{
    #|  "objects": [
    #|    {
    #|      "oid": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    #|      "size": 5000,
    #|      "error": {
    #|        "code": 404,
    #|        "message": "Object not found"
    #|      }
    #|    }
    #|  ]
    #|}
  let (actions, errors) = lfs_parse_batch_response(json_str)
  assert_eq(actions.length(), 0)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].oid, "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
  assert_eq(errors[0].code, 404)
  assert_eq(errors[0].message, "Object not found")
}

///|
test "lfs_parse_batch_response: mixed success and error" {
  let json_str =
    #|{
    #|  "objects": [
    #|    {
    #|      "oid": "aaaa1234567890abcdef1234567890abcdef1234567890abcdef1234567890aa",
    #|      "size": 100,
    #|      "actions": {
    #|        "download": {
    #|          "href": "https://example.com/obj1"
    #|        }
    #|      }
    #|    },
    #|    {
    #|      "oid": "bbbb1234567890abcdef1234567890abcdef1234567890abcdef1234567890bb",
    #|      "size": 200,
    #|      "error": {
    #|        "code": 410,
    #|        "message": "Gone"
    #|      }
    #|    }
    #|  ]
    #|}
  let (actions, errors) = lfs_parse_batch_response(json_str)
  assert_eq(actions.length(), 1)
  assert_eq(errors.length(), 1)
}
