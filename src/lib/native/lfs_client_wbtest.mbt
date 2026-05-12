///|
test "lfs_build_batch_request_json: single object" {
  let ptr = @bitlib.parse_lfs_pointer(
    b"version https://git-lfs.github.com/spec/v1\noid sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd\nsize 9876\n",
  ).unwrap()
  let objects : Array[@bitlib.LfsPointer] = [ptr]
  let json_str = lfs_build_batch_request_json(objects)
  let parsed = @json.parse(json_str)
  guard parsed is Json::Object(obj) else {
    assert_true(false)
    return
  }
  @test.assert_eq(obj.get("operation"), Some(Json::string("download")))
  guard obj.get("objects") is Some(Json::Array(arr)) else {
    assert_true(false)
    return
  }
  @test.assert_eq(arr.length(), 1)
  guard arr[0] is Json::Object(o) else {
    assert_true(false)
    return
  }
  @test.assert_eq(
    o.get("oid"),
    Some(
      Json::string(
        "abc123def456abc123def456abc123def456abc123def456abc123def456abcd",
      ),
    ),
  )
  @test.assert_eq(o.get("size"), Some(Json::number(9876.0)))
}

///|
test "lfs_build_batch_upload_request_json: single object" {
  let ptr = @bitlib.parse_lfs_pointer(
    b"version https://git-lfs.github.com/spec/v1\noid sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abcd\nsize 9876\n",
  ).unwrap()
  let objects : Array[@bitlib.LfsPointer] = [ptr]
  let json_str = lfs_build_batch_upload_request_json(objects)
  let parsed = @json.parse(json_str)
  guard parsed is Json::Object(obj) else {
    assert_true(false)
    return
  }
  @test.assert_eq(obj.get("operation"), Some(Json::string("upload")))
  guard obj.get("objects") is Some(Json::Array(arr)) else {
    assert_true(false)
    return
  }
  @test.assert_eq(arr.length(), 1)
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
  @test.assert_eq(actions.length(), 1)
  @test.assert_eq(errors.length(), 0)
  @test.assert_eq(
    actions[0].oid,
    "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
  @test.assert_eq(actions[0].size, 5000L)
  @test.assert_eq(actions[0].href, "https://example.com/download/obj1")
  @test.assert_eq(actions[0].headers.get("Authorization"), Some("Bearer token123"))
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
  @test.assert_eq(actions.length(), 0)
  @test.assert_eq(errors.length(), 1)
  @test.assert_eq(
    errors[0].oid,
    "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
  @test.assert_eq(errors[0].code, 404)
  @test.assert_eq(errors[0].message, "Object not found")
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
  @test.assert_eq(actions.length(), 1)
  @test.assert_eq(errors.length(), 1)
}

///|
test "lfs_get_cached_object: returns None when not cached" {
  let fs = @osfs.OsFs::new()
  let result = lfs_get_cached_object(
    fs, "/tmp/nonexistent-git-dir-lfs-test", "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  )
  @test.assert_eq(result, None)
}

///|
test "lfs_upload_url_for_remote: remote lfsurl is used before derived url" {
  let fs = @bit.TestFs::new()
  fs.mkdir_p("/repo/.git")
  fs.write_string(
    "/repo/.git/config", "[remote \"origin\"]\n\turl = https://example.com/repo.git\n\tlfsurl = https://lfs.example/custom\n",
  )

  @test.assert_eq(
    lfs_upload_url_for_remote(
      fs,
      "/repo/.git",
      "https://example.com/repo.git",
      remote_name="origin",
    ),
    "https://lfs.example/custom",
  )
}

///|
fn lfs_upload_wbtest_parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => "/"
    Some(0) => "/"
    Some(i) => String::unsafe_substring(path, start=0, end=i)
  }
}

///|
async test "lfs_upload_pack_objects_with_http: uploads cached pointer content" {
  let fs = @bit.TestFs::new()
  let git_dir = "/repo/.git"
  fs.mkdir_p(git_dir)
  let oid = "86bec3d4af0e92c6edc5cf2130ea556ec049d59f9a5082d19cda1c459d655cb6"
  let content = b"upload me\n"
  let cache_path = @bitlib.lfs_object_path(git_dir, oid)
  fs.mkdir_p(lfs_upload_wbtest_parent_dir(cache_path))
  fs.write_file(cache_path, content)
  let pointer = @utf8.encode(
    "version https://git-lfs.github.com/spec/v1\noid sha256:\{oid}\nsize 10\n",
  )
  let objects = [
    @bit.PackObject::new(@bit.ObjectType::Blob, pointer),
    @bit.PackObject::new(@bit.ObjectType::Blob, b"regular blob"),
  ]
  let post_urls : Array[String] = []
  let post_content_types : Array[String] = []
  let post_bodies : Array[String] = []
  let put_urls : Array[String] = []
  let put_bodies : Array[Bytes] = []
  let put_auth_headers : Array[String] = []
  let http_post = async fn(
    url : String,
    body : Bytes,
    headers : Map[String, String],
  ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
    @async.sleep(0) catch {
      err => raise @bit.GitError::IoError(err.to_string())
    }
    if url.length() == -1 {
      raise @bit.GitError::IoError("unreachable")
    }
    post_urls.push(url)
    post_content_types.push(headers.get("Content-Type").unwrap_or(""))
    post_bodies.push(@utf8.decode_lossy(body[:]))
    let response = @utf8.encode(
      "{\"objects\":[{\"oid\":\"\{oid}\",\"size\":10,\"actions\":{\"upload\":{\"href\":\"https://lfs.example/upload/\{oid}\",\"header\":{\"Authorization\":\"Bearer token\"}}}}]}",
    )
    (@bit.HttpResponse::new(200), response)
  }
  let http_put = async fn(
    url : String,
    body : Bytes,
    headers : Map[String, String],
  ) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
    @async.sleep(0) catch {
      err => raise @bit.GitError::IoError(err.to_string())
    }
    if url.length() == -1 {
      raise @bit.GitError::IoError("unreachable")
    }
    put_urls.push(url)
    put_bodies.push(body)
    put_auth_headers.push(headers.get("Authorization").unwrap_or(""))
    (@bit.HttpResponse::new(200), b"")
  }

  let errors = lfs_upload_pack_objects_with_http(
    fs, git_dir, "https://example.com/repo.git/info/lfs", objects, http_post, http_put,
  )

  @test.assert_eq(errors.length(), 0)
  @test.assert_eq(post_urls[0], "https://example.com/repo.git/info/lfs/objects/batch")
  @test.assert_eq(post_content_types[0], "application/vnd.git-lfs+json")
  assert_true(post_bodies[0].contains("\"operation\":\"upload\""))
  @test.assert_eq(put_urls[0], "https://lfs.example/upload/\{oid}")
  @test.assert_eq(put_bodies[0], content)
  @test.assert_eq(put_auth_headers[0], "Bearer token")
}
