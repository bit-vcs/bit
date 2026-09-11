///|
/// In-memory backend.
///
/// Deliberately faithful to S3 rather than convenient: the version tag is
/// derived from content, exactly as an S3 ETag is, so a test that would break
/// against a real bucket breaks here too. It also carries fault injection,
/// because the `Unknown` write outcome is the one a WAL is most likely to
/// mishandle and the hardest to provoke against a live store.
pub struct MemStore {
  objects : Map[String, Bytes]
  /// Number of subsequent writes to answer `Unknown` without applying them.
  mut fail_puts_unknown : Int
  /// Number of subsequent writes to apply and *then* answer `Unknown`, which
  /// is the harder half of the indeterminate case: the data landed but the
  /// caller was never told.
  mut silent_puts : Int
  /// Cap on entries returned per `list` page, to exercise pagination.
  mut page_size : Int
}

///|
pub fn MemStore::new() -> MemStore {
  { objects: Map([]), fail_puts_unknown: 0, silent_puts: 0, page_size: 1000 }
}

///|
/// Answer the next `n` writes with `Unknown` without applying them.
pub fn MemStore::fail_next_puts(self : MemStore, n : Int) -> Unit {
  self.fail_puts_unknown = n
}

///|
/// Apply the next `n` writes but answer `Unknown`, simulating a response lost
/// after the store committed.
pub fn MemStore::silence_next_puts(self : MemStore, n : Int) -> Unit {
  self.silent_puts = n
}

///|
/// Force short listing pages so callers must handle continuation.
pub fn MemStore::set_page_size(self : MemStore, n : Int) -> Unit {
  self.page_size = if n < 1 { 1 } else { n }
}

///|
pub fn MemStore::len(self : MemStore) -> Int {
  self.objects.length()
}

///|
/// Version tag for a body. Content-derived, like an S3 ETag: writing
/// identical bytes twice yields the same tag, and callers must not assume a
/// tag changes just because a write happened.
pub fn mem_etag(body : Bytes) -> String {
  @hash.hex_encode(@hash.sha256_raw(body))
}

///|
fn mem_slice(body : Bytes, range : ByteRange) -> Bytes {
  let len = body.length().to_int64()
  let start = if range.start < 0L { 0L } else { range.start }
  if start >= len {
    return Bytes::new(0)
  }
  let last = if range.end < 0L || range.end >= len {
    len - 1L
  } else {
    range.end
  }
  if last < start {
    return Bytes::new(0)
  }
  let n = (last - start + 1L).to_int()
  let base = start.to_int()
  Bytes::makei(n, i => body[base + i])
}

///|
pub impl ObjectStore for MemStore with fn get(self, key) {
  match self.objects.get(key) {
    Some(body) => GetOutcome::Found(body, mem_etag(body))
    None => GetOutcome::Missing
  }
}

///|
pub impl ObjectStore for MemStore with fn get_range(self, key, range) {
  match self.objects.get(key) {
    Some(body) => GetOutcome::Found(mem_slice(body, range), mem_etag(body))
    None => GetOutcome::Missing
  }
}

///|
pub impl ObjectStore for MemStore with fn get_if_none_match(self, key, etag) {
  match self.objects.get(key) {
    Some(body) => {
      let current = mem_etag(body)
      if current == etag {
        GetOutcome::NotModified
      } else {
        GetOutcome::Found(body, current)
      }
    }
    None => GetOutcome::Missing
  }
}

///|
pub impl ObjectStore for MemStore with fn put(self, key, body, condition) {
  if self.fail_puts_unknown > 0 {
    self.fail_puts_unknown -= 1
    return PutOutcome::Unknown
  }
  let existing = self.objects.get(key)
  let allowed = match condition {
    Unconditional => true
    IfNotExists => existing is None
    IfMatch(expected) =>
      match existing {
        Some(current) => mem_etag(current) == expected
        None => false
      }
  }
  if !allowed {
    return PutOutcome::NotApplied
  }
  self.objects[key] = body
  if self.silent_puts > 0 {
    self.silent_puts -= 1
    return PutOutcome::Unknown
  }
  PutOutcome::Applied(mem_etag(body))
}

///|
pub impl ObjectStore for MemStore with fn delete(self, key) {
  self.objects.remove(key)
}

///|
pub impl ObjectStore for MemStore with fn list(self, prefix, after) {
  let keys : Array[String] = []
  for key in self.objects.keys() {
    if key.has_prefix(prefix) && (after == "" || lex_lt(after, key)) {
      keys.push(key)
    }
  }
  keys.sort_by((a, b) => lex_compare(a, b))
  let entries : Array[ObjEntry] = []
  let limit = if keys.length() < self.page_size {
    keys.length()
  } else {
    self.page_size
  }
  for i in 0..<limit {
    let key = keys[i]
    let body = self.objects.get(key).unwrap()
    entries.push({ key, size: body.length().to_int64(), etag: mem_etag(body) })
  }
  let next = if keys.length() > limit { Some(keys[limit - 1]) } else { None }
  { entries, next }
}

///|
pub impl ObjectStore for MemStore with fn supports_cas(_self) {
  true
}
