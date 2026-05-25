///| Benchmarks for object construction and hashing.
///
/// Run with:
///   moon bench -p mizchi/bit/object --target native -f bench_test.mbt
///
/// `create_*` and `hash_object_content` sit on every write path.

///|
fn bench_make_blob_bytes(len : Int) -> Bytes {
  Bytes::makei(len, fn(i) { ((i * 31 + 7) % 251).to_byte() })
}

///|
fn bench_make_tree_entries(count : Int) -> Array[TreeEntry] {
  let entries : Array[TreeEntry] = []
  let zero_id = ObjectId::new(FixedArray::make(20, b'\x00'))
  for i in 0..<count {
    entries.push(TreeEntry::new("100644", "file_\{i}.txt", zero_id))
  }
  entries
}

///|
let bench_blob_1k : Bytes = bench_make_blob_bytes(1024)

///|
let bench_blob_64k : Bytes = bench_make_blob_bytes(64 * 1024)

///|
let bench_tree_entries_10 : Array[TreeEntry] = bench_make_tree_entries(10)

///|
let bench_tree_entries_100 : Array[TreeEntry] = bench_make_tree_entries(100)

///|
let bench_tree_entries_1000 : Array[TreeEntry] = bench_make_tree_entries(1000)

///|
test "bench hash_blob 1 KiB" (b : @bench.T) {
  b.bench(fn() {
    let id = hash_blob(bench_blob_1k)
    b.keep(id.bytes.length())
  })
}

///|
test "bench hash_blob 64 KiB" (b : @bench.T) {
  b.bench(fn() {
    let id = hash_blob(bench_blob_64k)
    b.keep(id.bytes.length())
  })
}

///|
test "bench create_blob 1 KiB" (b : @bench.T) {
  b.bench(fn() {
    let (id, _compressed) = create_blob(bench_blob_1k)
    b.keep(id.bytes.length())
  })
}

///|
test "bench create_blob 64 KiB" (b : @bench.T) {
  b.bench(fn() {
    let (id, compressed) = create_blob(bench_blob_64k)
    b.keep(id.bytes.length() + compressed.length())
  })
}

///|
test "bench serialize_tree 10 entries" (b : @bench.T) {
  b.bench(fn() {
    let bytes = serialize_tree(bench_tree_entries_10)
    b.keep(bytes.length())
  })
}

///|
test "bench serialize_tree 100 entries" (b : @bench.T) {
  b.bench(fn() {
    let bytes = serialize_tree(bench_tree_entries_100)
    b.keep(bytes.length())
  })
}

///|
test "bench serialize_tree 1000 entries" (b : @bench.T) {
  b.bench(fn() {
    let bytes = serialize_tree(bench_tree_entries_1000)
    b.keep(bytes.length())
  })
}

///|
test "bench create_tree 100 entries" (b : @bench.T) {
  b.bench(fn() {
    let (id, compressed) = create_tree(bench_tree_entries_100)
    b.keep(id.bytes.length() + compressed.length())
  })
}

///|
test "bench create_tree 1000 entries" (b : @bench.T) {
  b.bench(fn() {
    let (id, compressed) = create_tree(bench_tree_entries_1000)
    b.keep(id.bytes.length() + compressed.length())
  })
}
