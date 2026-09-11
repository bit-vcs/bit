///|
/// The WAL engine.
///
/// One compare-and-swap on the image object is the only thing that makes a
/// commit visible. There is no lease, no election and no quorum: the store's
/// conditional write is the whole coordination mechanism.

///|
pub struct Wal[S] {
  store : S
  /// Key prefix for this log, e.g. `repos/acme/app`.
  prefix : String
  /// Last image read, and the version tag it was read at. The tag is empty
  /// when the image has not been read, or is known not to exist.
  mut image : WalImage
  mut etag : String
  /// Whether `image`/`etag` reflect a completed read.
  mut loaded : Bool
  max_attempts : Int
  max_image_bytes : Int
}

///|
pub fn[S] Wal::new(
  store : S,
  prefix : String,
  max_attempts? : Int = DEFAULT_MAX_ATTEMPTS,
  max_image_bytes? : Int = DEFAULT_MAX_IMAGE_BYTES,
) -> Wal[S] {
  {
    store,
    prefix,
    image: WalImage::empty(),
    etag: "",
    loaded: false,
    max_attempts,
    max_image_bytes,
  }
}

///|
pub fn[S] Wal::image_key(self : Wal[S]) -> String {
  "\{self.prefix}/wal.json"
}

///|
pub fn[S] Wal::payload_key(self : Wal[S], content_id : String) -> String {
  "\{self.prefix}/payloads/\{content_id}"
}

///|
pub fn[S] Wal::snapshot_key(self : Wal[S], content_id : String) -> String {
  "\{self.prefix}/snapshots/\{content_id}"
}

///|
/// Content address for a blob: the same bytes always get the same key, which
/// is what makes writing one idempotent.
pub fn content_id(body : Bytes) -> String {
  @hash.hex_encode(@hash.sha256_raw(body))
}

///|
/// Refresh the cached image.
///
/// After the first read this is a conditional GET: an unchanged log costs one
/// request that transfers nothing, which is what makes a replica cheap to
/// keep fresh.
pub async fn[S : @objstore.ObjectStore] Wal::sync(
  self : Wal[S],
) -> Unit raise @bit.GitError {
  let key = self.image_key()
  let outcome = if self.loaded && self.etag != "" {
    self.store.get_if_none_match(key, self.etag)
  } else {
    self.store.get(key)
  }
  match outcome {
    NotModified => ()
    Found(body, etag) => {
      self.image = decode_image(body)
      self.etag = etag
      self.loaded = true
    }
    Missing => {
      // Either the log has never been written, or it was deleted underneath
      // us. Both mean "there is nothing committed", and a create-only write
      // is the correct next move.
      self.image = WalImage::empty()
      self.etag = ""
      self.loaded = true
    }
  }
}

///|
/// The live entries as of the last `sync`.
pub fn[S] Wal::entries(self : Wal[S]) -> Array[WalEntry] {
  self.image.entries
}

///|
/// Sequence of the newest entry as of the last `sync`.
pub fn[S] Wal::head_seq(self : Wal[S]) -> Int64 {
  self.image.head_seq()
}

///|
/// Snapshot key as of the last `sync`, empty when nothing has been folded.
pub fn[S] Wal::snapshot(self : Wal[S]) -> String {
  self.image.snapshot
}

///|
pub fn[S] Wal::settings(self : Wal[S]) -> String {
  self.image.settings
}

///|
/// Store a payload under its content address.
///
/// Safe to repeat: the key is derived from the bytes, so a repeat writes what
/// is already there. Returns the content id to reference from an entry.
pub async fn[S : @objstore.ObjectStore] Wal::put_payload(
  self : Wal[S],
  body : Bytes,
) -> String raise @bit.GitError {
  let id = content_id(body)
  let outcome = @objstore.put_immutable(self.store, self.payload_key(id), body)
  match outcome {
    Applied(_) => id
    NotApplied =>
      // put_immutable already folds the lost-race case into Applied, so this
      // is a precondition failure that should not be reachable.
      raise @bit.GitError::IoError("payload write refused for \{id}")
    Unknown =>
      raise @bit.GitError::IoError(
        "payload write for \{id} is indeterminate; retry before committing",
      )
  }
}

///|
pub async fn[S : @objstore.ObjectStore] Wal::get_payload(
  self : Wal[S],
  content_id : String,
) -> Bytes raise @bit.GitError {
  let key = self.payload_key(content_id)
  let (body, _) = self.store.get(key).unwrap(key)
  body
}

///|
/// Whether every one of these idempotency keys is already in the image.
///
/// This is how an indeterminate write is resolved: rather than guessing
/// whether the request landed, the writer looks for its own mark.
fn already_committed(image : WalImage, keys : Array[String]) -> Bool {
  if keys.length() == 0 {
    return false
  }
  let present : Map[String, Bool] = Map([])
  for entry in image.entries {
    if entry.idempotency_key != "" {
      present[entry.idempotency_key] = true
    }
  }
  for key in keys {
    if key == "" || !present.contains(key) {
      return false
    }
  }
  true
}

///|
fn idempotency_keys(entries : Array[WalEntry]) -> Array[String] {
  let out : Array[String] = []
  for entry in entries {
    out.push(entry.idempotency_key)
  }
  out
}

///|
/// Append entries as one atomic commit.
///
/// Several entries in one call are a group commit: they cost a single
/// compare-and-swap between them, which is what keeps concurrent pushes from
/// each paying their own round trip.
///
/// Entries carry payload keys but not payload bytes — write those with
/// `put_payload` first. That ordering is deliberate: a payload is content
/// addressed and immutable, so writing one that is never referenced leaves
/// garbage, while committing an entry that references a payload not yet
/// written would leave the log describing something that does not exist.
pub async fn[S : @objstore.ObjectStore] Wal::append(
  self : Wal[S],
  entries : Array[WalEntry],
) -> CommitOutcome raise @bit.GitError {
  if entries.length() == 0 {
    self.sync()
    return CommitOutcome::Committed(self.head_seq())
  }
  if !self.store.supports_cas() {
    raise @bit.GitError::IoError(
      "backing store does not support conditional writes; " +
      "a log cannot be hosted on it safely",
    )
  }
  let keys = idempotency_keys(entries)
  for _ in 0..<self.max_attempts {
    self.sync()

    // Resolve a previous indeterminate attempt before doing anything else.
    if already_committed(self.image, keys) {
      return CommitOutcome::Committed(self.head_seq())
    }
    let base = self.image.head_seq()
    let next_entries : Array[WalEntry] = []
    for entry in self.image.entries {
      next_entries.push(entry)
    }
    let mut seq = base
    for entry in entries {
      seq += 1L
      next_entries.push({
        seq,
        kind: entry.kind,
        payload_keys: entry.payload_keys,
        data: entry.data,
        idempotency_key: entry.idempotency_key,
      })
    }
    let next_image : WalImage = {
      version: WAL_FORMAT_VERSION,
      snapshot: self.image.snapshot,
      snapshot_seq: self.image.snapshot_seq,
      snapshot_payloads: self.image.snapshot_payloads,
      entries: next_entries,
      settings: self.image.settings,
    }
    let body = encode_image(next_image)
    if body.length() > self.max_image_bytes {
      raise @bit.GitError::IoError(
        "WAL image would be \{body.length()} bytes, over the " +
        "\{self.max_image_bytes} byte limit; compact before appending",
      )
    }
    let condition = if self.etag == "" {
      @objstore.PutCondition::IfNotExists
    } else {
      @objstore.PutCondition::IfMatch(self.etag)
    }
    match self.store.put(self.image_key(), body, condition) {
      Applied(new_etag) => {
        self.image = next_image
        self.etag = new_etag
        self.loaded = true
        return CommitOutcome::Committed(seq)
      }
      // Someone else committed first. Re-read and rebuild on top of them.
      NotApplied => self.invalidate()
      // The write may have landed. The next pass re-reads and looks for our
      // idempotency keys, so this neither double-applies nor gives up.
      Unknown => self.invalidate()
    }
  }
  CommitOutcome::Contended
}

///|
/// Drop the cached image so the next `sync` performs a full read.
fn[S] Wal::invalidate(self : Wal[S]) -> Unit {
  self.loaded = false
  self.etag = ""
}

///|
/// Replace the settings blob, under the same compare-and-swap discipline as
/// an append.
pub async fn[S : @objstore.ObjectStore] Wal::set_settings(
  self : Wal[S],
  settings : String,
) -> CommitOutcome raise @bit.GitError {
  for _ in 0..<self.max_attempts {
    self.sync()
    if self.image.settings == settings {
      return CommitOutcome::Committed(self.head_seq())
    }
    let next_image : WalImage = {
      version: WAL_FORMAT_VERSION,
      snapshot: self.image.snapshot,
      snapshot_seq: self.image.snapshot_seq,
      snapshot_payloads: self.image.snapshot_payloads,
      entries: self.image.entries,
      settings,
    }
    let condition = if self.etag == "" {
      @objstore.PutCondition::IfNotExists
    } else {
      @objstore.PutCondition::IfMatch(self.etag)
    }
    match self.store.put(self.image_key(), encode_image(next_image), condition) {
      Applied(new_etag) => {
        self.image = next_image
        self.etag = new_etag
        self.loaded = true
        return CommitOutcome::Committed(next_image.head_seq())
      }
      NotApplied => self.invalidate()
      Unknown => self.invalidate()
    }
  }
  CommitOutcome::Contended
}
