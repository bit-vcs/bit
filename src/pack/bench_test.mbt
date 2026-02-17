///| Benchmarks for packfile operations

///|
/// Run with:
/// - moon bench -p mizchi/bit/pack --target native -f bench_test.mbt

///|
fn make_blob_objects(count : Int) -> Array[@bit.PackObject] {
  let objects : Array[@bit.PackObject] = []
  for i in 0..<count {
    let data = Bytes::from_array(
      "blob content \{i} with some padding to make it realistic\n"
      .to_array()
      .map(fn(c) { c.to_int().to_byte() }),
    )
    objects.push(@bit.PackObject::new(@bit.ObjectType::Blob, data))
  }
  objects
}

///|
fn make_similar_blob_objects(count : Int) -> Array[@bit.PackObject] {
  let base = "This is a shared base content that will be used for delta compression. It contains enough text to make delta encoding worthwhile. Line number: "
  let objects : Array[@bit.PackObject] = []
  for i in 0..<count {
    let text = base + i.to_string() + "\nSome trailing content.\n"
    let data = Bytes::from_array(
      text.to_array().map(fn(c) { c.to_int().to_byte() }),
    )
    objects.push(@bit.PackObject::new(@bit.ObjectType::Blob, data))
  }
  objects
}

///|
let bench_pack_small : Bytes = @pack.create_packfile(make_blob_objects(3))

///|
let bench_pack_100 : Bytes = @pack.create_packfile(make_blob_objects(100))

///|
let bench_objects_10 : Array[@bit.PackObject] = make_blob_objects(10)

///|
let bench_objects_100 : Array[@bit.PackObject] = make_blob_objects(100)

///|
let bench_similar_100 : Array[@bit.PackObject] = make_similar_blob_objects(100)

///|
test "bench parse_packfile small" (b : @bench.T) {
  b.bench(fn() {
    let objs = try! @pack.parse_packfile(bench_pack_small)
    b.keep(objs.length())
  })
}

///|
test "bench parse_packfile 100 objects" (b : @bench.T) {
  b.bench(fn() {
    let objs = try! @pack.parse_packfile(bench_pack_100)
    b.keep(objs.length())
  })
}

///|
test "bench create_packfile 10 objects" (b : @bench.T) {
  b.bench(fn() {
    let pack = @pack.create_packfile(bench_objects_10)
    b.keep(pack.length())
  })
}

///|
test "bench create_packfile 100 objects" (b : @bench.T) {
  b.bench(fn() {
    let pack = @pack.create_packfile(bench_objects_100)
    b.keep(pack.length())
  })
}

///|
test "bench create_packfile_with_delta 100" (b : @bench.T) {
  b.bench(fn() {
    let pack = @pack.create_packfile_with_delta(
      bench_similar_100,
      @bit.PackDeltaMode::OfsDelta,
    )
    b.keep(pack.length())
  })
}

///|
test "bench build_pack_index" (b : @bench.T) {
  b.bench(fn() {
    let idx = try! @pack.build_pack_index(bench_pack_100)
    b.keep(idx.length())
  })
}

///|
test "bench encode_type_and_size" (b : @bench.T) {
  b.bench(fn() {
    let buf : Array[Byte] = []
    for i in 0..<1000 {
      buf.clear()
      @pack.encode_type_and_size(3, i * 100, buf)
    }
    b.keep(buf.length())
  })
}

///|
fn make_encoded_header() -> Bytes {
  let buf : Array[Byte] = []
  @pack.encode_type_and_size(3, 65536, buf)
  Bytes::from_array(buf)
}

///|
let bench_encoded_header : Bytes = make_encoded_header()

///|
test "bench decode_type_and_size_at" (b : @bench.T) {
  b.bench(fn() {
    let mut sum = 0
    for _ in 0..<1000 {
      let (type_id, size, _) = try! @pack.decode_type_and_size_at(
        bench_encoded_header, 0,
      )
      sum = sum + type_id + size
    }
    b.keep(sum)
  })
}
