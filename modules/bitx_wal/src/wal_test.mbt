///|
fn text(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn entry(kind : String, data : String, key : String) -> WalEntry {
  WalEntry::new(kind, data, idempotency_key=key)
}

///|
fn kinds_and_data(entries : Array[WalEntry]) -> String {
  let parts : Array[String] = []
  for e in entries {
    parts.push("\{e.seq}:\{e.kind}:\{e.data}")
  }
  parts.join(",")
}

///|
async test "wal: an absent log reads as empty rather than failing" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "repos/acme/app")
  wal.sync()
  inspect(wal.head_seq(), content="0")
  inspect(wal.entries().length(), content="0")
  inspect(wal.snapshot(), content="")
}

///|
async test "wal: an append is visible to a reader that never saw the writer" {
  let store = @objstore.MemStore::new()
  let writer = Wal::new(store, "p")
  inspect(writer.append([entry("push", "refs/heads/main", "k1")]), content="Committed(1)")
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(kinds_and_data(reader.entries()), content="1:push:refs/heads/main")
}

///|
async test "wal: several entries in one call cost one commit and stay ordered" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let outcome = wal.append([
    entry("push", "a", "k1"),
    entry("push", "b", "k2"),
    entry("settings", "c", "k3"),
  ])
  inspect(outcome, content="Committed(3)")
  inspect(kinds_and_data(wal.entries()), content="1:push:a,2:push:b,3:settings:c")
  // One image object, one payload-free commit: the group did not cost three
  // separate rewrites.
  inspect(store.len(), content="1")
}

///|
async test "wal: a writer with a stale version rebases instead of clobbering" {
  let store = @objstore.MemStore::new()
  let a = Wal::new(store, "p")
  let b : Wal[@objstore.MemStore] = Wal::new(store, "p")
  a.sync()
  b.sync()
  // b commits while a still holds the version it read.
  inspect(b.append([entry("push", "from-b", "kb")]), content="Committed(1)")
  // a's compare-and-swap fails, so it re-reads and appends on top.
  inspect(a.append([entry("push", "from-a", "ka")]), content="Committed(2)")
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(
    kinds_and_data(reader.entries()),
    content="1:push:from-b,2:push:from-a",
  )
}

///|
async test "wal: a commit that lands but reports Unknown is not applied twice" {
  // The hard half of the indeterminate case. The store commits and the
  // response is lost; a writer that treats Unknown as failure and retries
  // blindly would write the entry a second time.
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  store.silence_next_puts(1)
  inspect(wal.append([entry("push", "once", "k1")]), content="Committed(1)")
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(kinds_and_data(reader.entries()), content="1:push:once")
}

///|
async test "wal: a commit that did not land is retried and applied once" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  store.fail_next_puts(1)
  inspect(wal.append([entry("push", "once", "k1")]), content="Committed(1)")
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(kinds_and_data(reader.entries()), content="1:push:once")
}

///|
async test "wal: re-sending an entry with the same key is a no-op" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  inspect(wal.append([entry("push", "a", "k1")]), content="Committed(1)")
  // A client that never saw the first acknowledgement sends it again.
  let retry : Wal[@objstore.MemStore] = Wal::new(store, "p")
  inspect(retry.append([entry("push", "a", "k1")]), content="Committed(1)")
  retry.sync()
  inspect(kinds_and_data(retry.entries()), content="1:push:a")
}

///|
async test "wal: entries without an idempotency key are always new" {
  // Opting out is allowed, and the consequence is explicit: two identical
  // unkeyed entries are two entries.
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([WalEntry::new("push", "a")])
  let _ = wal.append([WalEntry::new("push", "a")])
  inspect(kinds_and_data(wal.entries()), content="1:push:a,2:push:a")
}

///|
async test "wal: an empty append reports the current head without writing" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([entry("push", "a", "k1")])
  let before = store.len()
  inspect(wal.append([]), content="Committed(1)")
  inspect(store.len() == before, content="true")
}

///|
async test "wal: payloads are content addressed, so writing one twice is free" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let id1 = wal.put_payload(text("packdata"))
  let id2 = wal.put_payload(text("packdata"))
  inspect(id1 == id2, content="true")
  // One payload object, not two.
  inspect(store.len(), content="1")
  inspect(@utf8.decode_lossy(wal.get_payload(id1)[:]), content="packdata")
}

///|
async test "wal: settings ride along with the image" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  inspect(wal.set_settings("deny-force-push=true"), content="Committed(0)")
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(reader.settings(), content="deny-force-push=true")
}

///|
/// Fold that simply concatenates the folded entries' data onto the previous
/// snapshot, and keeps every payload key it saw.
let concat_fold : async (Bytes, Array[WalEntry]) -> Fold raise @bit.GitError = (
  previous,
  folding,
) => {
  let parts : Array[String] = []
  if previous.length() > 0 {
    parts.push(@utf8.decode_lossy(previous[:]))
  }
  let retained : Array[String] = []
  for e in folding {
    parts.push(e.data)
    for key in e.payload_keys {
      retained.push(key)
    }
  }
  { body: @utf8.encode(parts.join("|")), retained_payloads: retained }
}

///|
async test "wal: compaction folds a prefix and leaves the tail live" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([
    entry("push", "a", "k1"),
    entry("push", "b", "k2"),
    entry("push", "c", "k3"),
    entry("push", "d", "k4"),
  ])
  inspect(wal.compact(2L, concat_fold), content="Committed(2)")
  inspect(kinds_and_data(wal.entries()), content="3:push:c,4:push:d")
  // The head does not move backwards just because entries were folded away.
  inspect(wal.head_seq(), content="4")
  inspect(@utf8.decode_lossy(wal.read_snapshot()[:]), content="a|b")
}

///|
async test "wal: a second compaction folds onto the first" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([
    entry("push", "a", "k1"),
    entry("push", "b", "k2"),
    entry("push", "c", "k3"),
  ])
  let _ = wal.compact(1L, concat_fold)
  inspect(wal.compact(3L, concat_fold), content="Committed(3)")
  inspect(@utf8.decode_lossy(wal.read_snapshot()[:]), content="a|b|c")
  inspect(wal.entries().length(), content="0")
  inspect(wal.head_seq(), content="3")
}

///|
async test "wal: compacting to a point already folded is a no-op" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([entry("push", "a", "k1"), entry("push", "b", "k2")])
  let _ = wal.compact(2L, concat_fold)
  let snapshot = wal.snapshot()
  inspect(wal.compact(1L, concat_fold), content="Committed(2)")
  inspect(wal.snapshot() == snapshot, content="true")
}

///|
async test "wal: an append after compaction continues the sequence" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([entry("push", "a", "k1"), entry("push", "b", "k2")])
  let _ = wal.compact(2L, concat_fold)
  inspect(wal.append([entry("push", "c", "k3")]), content="Committed(3)")
  inspect(kinds_and_data(wal.entries()), content="3:push:c")
}

///|
async test "wal: a sweep removes orphaned payloads and keeps referenced ones" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let used = wal.put_payload(text("referenced"))
  let orphan = wal.put_payload(text("abandoned"))
  let _ = wal.append([
    WalEntry::new("push", "a", payload_keys=[used], idempotency_key="k1"),
  ])
  let doomed = wal.unreferenced_keys()
  inspect(doomed.length(), content="1")
  inspect(doomed[0], content="p/payloads/\{orphan}")
  let swept = wal.sweep_offline()
  inspect(swept.length(), content="1")
  // The referenced payload survived and is still readable.
  inspect(@utf8.decode_lossy(wal.get_payload(used)[:]), content="referenced")
}

///|
async test "wal: a sweep drops the snapshot that compaction superseded" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([entry("push", "a", "k1"), entry("push", "b", "k2")])
  let _ = wal.compact(1L, concat_fold)
  let first_snapshot = wal.snapshot()
  let _ = wal.compact(2L, concat_fold)
  let swept = wal.sweep_offline()
  inspect(swept.length(), content="1")
  inspect(swept[0], content="p/snapshots/\{first_snapshot}")
  // The live snapshot is untouched.
  inspect(@utf8.decode_lossy(wal.read_snapshot()[:]), content="a|b")
}

///|
async test "wal: payloads retained by a fold are not swept" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let kept = wal.put_payload(text("still-needed"))
  let _ = wal.append([
    WalEntry::new("push", "a", payload_keys=[kept], idempotency_key="k1"),
  ])
  // Folding the entry away must not make its payload look like garbage.
  let _ = wal.compact(1L, concat_fold)
  inspect(wal.unreferenced_keys().length(), content="0")
}

///|
async test "wal: an oversized image is refused rather than written" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p", max_image_bytes=200)
  let big = WalEntry::new("push", "x".repeat(500), idempotency_key="k1")
  let message = try {
    let _ = wal.append([big])
    "<no error>"
  } catch {
    e => e.to_string()
  }
  inspect(message.contains("compact before appending"), content="true")
  // Nothing was written.
  inspect(store.len(), content="0")
}

///|
async test "wal: a future format version is refused, not silently rewritten" {
  let store = @objstore.MemStore::new()
  let _ = store.put(
    "p/wal.json",
    text("{\"version\":99,\"entries\":[],\"snapshot\":\"\"}"),
    @objstore.PutCondition::Unconditional,
  )
  let wal = Wal::new(store, "p")
  let message = try {
    wal.sync()
    "<no error>"
  } catch {
    e => e.to_string()
  }
  inspect(message.contains("newer than supported"), content="true")
}

///|
async test "wal: contention is reported once the retry budget runs out" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p", max_attempts=3)
  store.fail_next_puts(3)
  inspect(wal.append([entry("push", "a", "k1")]), content="Contended")
  // The log is untouched: a Contended result never half-commits.
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(reader.entries().length(), content="0")
}

///|
/// A store that refuses to honour preconditions, like an older
/// S3-compatible server. Delegates everything else to a real MemStore.
struct NoCasStore {
  inner : @objstore.MemStore
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn get(self, key) {
  self.inner.get(key)
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn get_range(self, key, range) {
  self.inner.get_range(key, range)
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn get_if_none_match(
  self,
  key,
  etag,
) {
  self.inner.get_if_none_match(key, etag)
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn put(self, key, body, _c) {
  // The defining misbehaviour: the precondition is ignored.
  self.inner.put(key, body, @objstore.PutCondition::Unconditional)
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn delete(self, key) {
  self.inner.delete(key)
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn list(self, prefix, after) {
  self.inner.list(prefix, after)
}

///|
pub impl @objstore.ObjectStore for NoCasStore with fn supports_cas(_self) {
  false
}

///|
async test "wal: a store without compare-and-swap is refused up front" {
  // Failing here is the whole point: silently accepting such a store would
  // degrade every commit to last-writer-wins and lose entries under load.
  let store : NoCasStore = { inner: @objstore.MemStore::new() }
  let wal = Wal::new(store, "p")
  let message = try {
    let _ = wal.append([entry("push", "a", "k1")])
    "<no error>"
  } catch {
    e => e.to_string()
  }
  inspect(message.contains("does not support conditional writes"), content="true")
}

///|
async test "wal: a fresh read after many commits sees them all in order" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  for i in 0..<10 {
    let _ = wal.append([entry("push", "e\{i}", "k\{i}")])
  }
  let reader : Wal[@objstore.MemStore] = Wal::new(store, "p")
  reader.sync()
  inspect(reader.head_seq(), content="10")
  inspect(reader.entries()[0].data, content="e0")
  inspect(reader.entries()[9].data, content="e9")
}

///|
async test "wal: sync on an unchanged log transfers nothing" {
  let store = @objstore.MemStore::new()
  let wal = Wal::new(store, "p")
  let _ = wal.append([entry("push", "a", "k1")])
  wal.sync()
  // The conditional read reported NotModified, so the cached image stands.
  inspect(kinds_and_data(wal.entries()), content="1:push:a")
}
