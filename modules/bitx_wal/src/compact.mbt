///|
/// Compaction and garbage collection.
///
/// The image is rewritten in full on every commit, so its size is the price
/// of each commit. Compaction folds a prefix of the entries into a snapshot
/// object and drops them from the image, keeping that price bounded.

///|
/// What a fold produced: the snapshot bytes, and the payload keys the
/// snapshot still needs.
///
/// Reporting the retained payloads is the caller's job because only the
/// caller knows which of the folded entries' payloads survived the fold — a
/// Git repack, for instance, replaces several packs with one.
pub(all) struct Fold {
  body : Bytes
  retained_payloads : Array[String]
}

///|
/// Fold entries up to and including `through_seq` into a new snapshot.
///
/// `fold` receives the previous snapshot (empty on the first compaction) and
/// the entries being folded, and returns the new snapshot. It must be a pure
/// function of those inputs: it may run again after a lost race.
///
/// Returns the sequence the log is now folded through.
pub async fn[S : @objstore.ObjectStore] Wal::compact(
  self : Wal[S],
  through_seq : Int64,
  fold : async (Bytes, Array[WalEntry]) -> Fold raise @bit.GitError,
) -> CommitOutcome raise @bit.GitError {
  for _ in 0..<self.max_attempts {
    self.sync()
    if through_seq <= self.image.snapshot_seq {
      // Already folded this far, by us or by another maintainer.
      return CommitOutcome::Committed(self.image.snapshot_seq)
    }
    let folding : Array[WalEntry] = []
    let remaining : Array[WalEntry] = []
    for entry in self.image.entries {
      if entry.seq <= through_seq {
        folding.push(entry)
      } else {
        remaining.push(entry)
      }
    }
    if folding.length() == 0 {
      return CommitOutcome::Committed(self.image.snapshot_seq)
    }
    let previous = if self.image.snapshot == "" {
      Bytes::new(0)
    } else {
      let key = self.snapshot_key(self.image.snapshot)
      let (body, _) = self.store.get(key).unwrap(key)
      body
    }
    let folded = fold(previous, folding)
    let snapshot_id = content_id(folded.body)

    // Content-addressed and written create-only, so a snapshot can never
    // overwrite another and a re-run after a lost race is a no-op.
    let write = @objstore.put_immutable(
      self.store,
      self.snapshot_key(snapshot_id),
      folded.body,
    )
    match write {
      Applied(_) => ()
      NotApplied =>
        raise @bit.GitError::IoError(
          "snapshot write refused for \{snapshot_id}",
        )
      Unknown => {
        // The snapshot may or may not be there. Retrying is safe because the
        // key is derived from the content.
        self.invalidate()
        continue
      }
    }
    let next_image : WalImage = {
      version: WAL_FORMAT_VERSION,
      snapshot: snapshot_id,
      snapshot_seq: through_seq,
      snapshot_payloads: folded.retained_payloads,
      entries: remaining,
      settings: self.image.settings,
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
        return CommitOutcome::Committed(through_seq)
      }
      NotApplied => self.invalidate()
      Unknown => self.invalidate()
    }
  }
  CommitOutcome::Contended
}

///|
/// Read the current snapshot, or empty bytes when nothing has been folded.
pub async fn[S : @objstore.ObjectStore] Wal::read_snapshot(
  self : Wal[S],
) -> Bytes raise @bit.GitError {
  if self.image.snapshot == "" {
    return Bytes::new(0)
  }
  let key = self.snapshot_key(self.image.snapshot)
  let (body, _) = self.store.get(key).unwrap(key)
  body
}

///|
/// Keys that a sweep would delete: payloads and snapshots no longer
/// referenced by the image.
///
/// Separated from the deletion itself so a maintainer can report a sweep
/// before performing one, and so the decision is testable without destroying
/// anything.
pub async fn[S : @objstore.ObjectStore] Wal::unreferenced_keys(
  self : Wal[S],
) -> Array[String] raise @bit.GitError {
  self.sync()
  let live : Map[String, Bool] = Map([])
  for id in self.image.live_payloads() {
    live[self.payload_key(id)] = true
  }
  if self.image.snapshot != "" {
    live[self.snapshot_key(self.image.snapshot)] = true
  }
  let out : Array[String] = []
  for prefix in ["\{self.prefix}/payloads/", "\{self.prefix}/snapshots/"] {
    for entry in @objstore.list_all(self.store, prefix) {
      if !live.contains(entry.key) {
        out.push(entry.key)
      }
    }
  }
  out
}

///|
/// Delete unreferenced payloads and snapshots.
///
/// **Not safe to run against a log with writers in flight.** A payload is
/// written before the entry that references it lands, so between those two
/// moments it looks exactly like garbage. waltier makes the same restriction
/// for the same reason: collection is an offline operation.
///
/// Returns the keys removed.
pub async fn[S : @objstore.ObjectStore] Wal::sweep_offline(
  self : Wal[S],
) -> Array[String] raise @bit.GitError {
  let doomed = self.unreferenced_keys()
  for key in doomed {
    self.store.delete(key)
  }
  doomed
}
