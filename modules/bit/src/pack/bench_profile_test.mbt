///| Profiling benchmarks to isolate pack-objects bottleneck

///|
fn make_realistic_objects(count : Int) -> Array[@bit.PackObject] {
  // Simulate real repo: mix of blobs, trees, commits with similar content
  let objects : Array[@bit.PackObject] = []
  for i in 0..<count {
    let content = StringBuilder::new()
    // Each blob ~200 bytes with shared prefix (realistic for source files)
    content.write_string("// File auto-generated for testing\n")
    content.write_string("package main\n\nimport \"fmt\"\n\n")
    content.write_string("func main() {\n")
    content.write_string("    fmt.Println(\"version \{i}\")\n")
    content.write_string("    // Some shared boilerplate\n")
    for line in 0..<5 {
      content.write_string("    doWork(\{line})\n")
    }
    content.write_string("}\n")
    let text = content.to_string()
    let data = Bytes::from_array(
      text.to_array().map(fn(c) { c.to_int().to_byte() }),
    )
    objects.push(@bit.PackObject::new(@bit.ObjectType::Blob, data))
  }
  objects
}

///|
let profile_500 : Array[@bit.PackObject] = make_realistic_objects(500)

///|
test "bench profile: zlib compress 500 blobs" (b : @bench.T) {
  b.bench(fn() {
    let mut total = 0
    for obj in profile_500 {
      let compressed = @zlib.zlib_compress(obj.data)
      total += compressed.length()
    }
    b.keep(total)
  })
}

///|
test "bench profile: sha1 500 blobs" (b : @bench.T) {
  b.bench(fn() {
    let mut total = 0
    for obj in profile_500 {
      let id = @bit.hash_object_content(obj.obj_type, obj.data)
      total += id.bytes[0].to_int()
    }
    b.keep(total)
  })
}

///|
test "bench profile: delta compute 500 blobs" (b : @bench.T) {
  b.bench(fn() {
    let mut total = 0
    let mut prev : @bit.PackObject? = None
    for obj in profile_500 {
      match prev {
        Some(p) => {
          let delta = @pack.build_delta_pub(p.data, obj.data)
          total += delta.length()
        }
        None => ()
      }
      prev = Some(obj)
    }
    b.keep(total)
  })
}

///|
test "bench profile: Array[Byte] push 500x200B" (b : @bench.T) {
  b.bench(fn() {
    let arr : Array[Byte] = []
    for obj in profile_500 {
      for byte in obj.data {
        arr.push(byte)
      }
    }
    b.keep(arr.length())
  })
}

///|
test "bench profile: Array[Byte] collect 500x200B" (b : @bench.T) {
  b.bench(fn() {
    let parts : Array[Bytes] = []
    let mut total = 0
    for obj in profile_500 {
      parts.push(obj.data)
      total += obj.data.length()
    }
    let arr : Array[Byte] = Array::new(capacity=total)
    for part in parts {
      for i in 0..<part.length() {
        arr.push(part[i])
      }
    }
    b.keep(arr.length())
  })
}

///|
test "bench profile: full packfile 500 blobs" (b : @bench.T) {
  b.bench(fn() {
    let pack = @pack.create_packfile(profile_500)
    b.keep(pack.length())
  })
}

///|
test "bench profile: packfile with delta 500 blobs" (b : @bench.T) {
  b.bench(fn() {
    let pack = @pack.create_packfile_with_delta(
      profile_500,
      @bit.PackDeltaMode::OfsDelta,
    )
    b.keep(pack.length())
  })
}

///|
