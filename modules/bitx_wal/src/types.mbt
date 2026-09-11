///|
/// A write-ahead log over object storage, coordinated by nothing but
/// compare-and-swap.
///
/// The shape is waltier's: the whole live log is **one small object** — the
/// WAL image — holding a snapshot pointer plus the live entries, rewritten by
/// compare-and-swap on every commit. Large payloads are separate immutable
/// objects that entries only reference. See `docs/scalable-git-server.md`.
///
/// Keeping the entries *inside* the image is what makes the design safe
/// rather than merely simple. A log made of one object per sequence number
/// has to answer what an entry that was written but never committed means:
/// skipping it lets a later writer commit a range that contains it, and
/// waiting for it deadlocks on a writer that died. Here an entry does not
/// exist until the image that contains it lands, so there is no such state.
///
/// Nothing in this module knows about Git.

///|
/// What an entry records. The engine does not interpret `payload_keys` or
/// `data`; it guarantees only their ordering and durability.
pub(all) struct WalEntry {
  /// Position in the log, assigned by `append`. Ignored on input.
  seq : Int64
  /// Caller-defined discriminator, e.g. `push`, `settings`.
  kind : String
  /// Content-addressed payload keys this entry refers to.
  payload_keys : Array[String]
  /// Opaque caller data. The engine treats it as text.
  data : String
  /// Distinguishes a re-sent entry from a genuinely new one.
  ///
  /// This is what makes recovery from an indeterminate write safe: after an
  /// `Unknown` the writer re-reads the image and looks for its own key rather
  /// than guessing, so entries are never applied twice.
  idempotency_key : String
} derive(Eq)

///|
pub fn WalEntry::new(
  kind : String,
  data : String,
  payload_keys? : Array[String] = [],
  idempotency_key? : String = "",
) -> WalEntry {
  { seq: 0L, kind, payload_keys, data, idempotency_key }
}

///|
/// The WAL image: the only object whose rewrite makes anything visible.
pub(all) struct WalImage {
  version : Int
  /// Snapshot object key, or empty when nothing has been folded yet.
  snapshot : String
  /// The sequence the snapshot folds up to, inclusive.
  snapshot_seq : Int64
  /// Payload keys the snapshot still needs. Live entries carry their own.
  snapshot_payloads : Array[String]
  /// Entries after `snapshot_seq`, in order.
  entries : Array[WalEntry]
  /// Caller-defined configuration, carried here so a replica picks it up with
  /// the same conditional read that tells it the log moved.
  settings : String
} derive(Eq)

///|
pub fn WalImage::empty() -> WalImage {
  {
    version: WAL_FORMAT_VERSION,
    snapshot: "",
    snapshot_seq: 0L,
    snapshot_payloads: [],
    entries: [],
    settings: "",
  }
}

///|
/// Sequence of the last entry, folded or live.
pub fn WalImage::head_seq(self : WalImage) -> Int64 {
  if self.entries.length() == 0 {
    self.snapshot_seq
  } else {
    self.entries[self.entries.length() - 1].seq
  }
}

///|
/// Every payload key the image still depends on. Anything else under the
/// payload prefix is garbage.
pub fn WalImage::live_payloads(self : WalImage) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[String] = []
  for key in self.snapshot_payloads {
    if !seen.contains(key) {
      seen[key] = true
      out.push(key)
    }
  }
  for entry in self.entries {
    for key in entry.payload_keys {
      if !seen.contains(key) {
        seen[key] = true
        out.push(key)
      }
    }
  }
  out
}

///|
/// Bumped only for a change an older reader could not safely ignore.
pub const WAL_FORMAT_VERSION : Int = 1

///|
/// Outcome of a commit.
pub(all) enum CommitOutcome {
  /// Entries are durable and visible. Carries the new head sequence.
  Committed(Int64)
  /// Another writer won every attempt within the retry budget. The log is
  /// unchanged by this call.
  Contended
} derive(Eq)

///|
pub impl Show for CommitOutcome with fn output(self, logger) {
  match self {
    Committed(seq) => logger.write_string("Committed(\{seq})")
    Contended => logger.write_string("Contended")
  }
}

///|
/// How hard `append` tries before reporting contention. Each attempt costs a
/// read and a conditional write, so this is a cost ceiling as much as a
/// correctness one.
pub const DEFAULT_MAX_ATTEMPTS : Int = 8

///|
/// Refuse to write an image larger than this.
///
/// waltier's equivalent default is 64 MiB. An image is rewritten in full on
/// every commit, so its size is the per-commit cost: letting it grow without
/// bound turns every push into a multi-megabyte round trip. Exceeding it
/// means compaction is overdue, which is a caller error rather than a
/// storage failure, so it is reported as one.
pub const DEFAULT_MAX_IMAGE_BYTES : Int = 64 * 1024 * 1024
