///|
/// Core value types for the object-store abstraction.
///
/// The shape follows the two designs this module is modelled on: walgit's
/// "the manifest CAS is the only commit point" and waltier's insistence that
/// a write outcome is a three-way answer, not a boolean. See
/// `docs/scalable-git-server.md`.

///|
/// Precondition attached to a write.
///
/// The backing store maps these onto its own primitive:
/// S3 / R2 use `If-None-Match: *` and `If-Match: <etag>`; GCS uses
/// `ifGenerationMatch=0` and `ifGenerationMatch=<generation>`.
pub(all) enum PutCondition {
  /// Overwrite unconditionally. Only safe for content-addressed keys.
  Unconditional
  /// Create only. Fails if the key already exists.
  IfNotExists
  /// Compare-and-swap against a known version.
  IfMatch(String)
} derive(Eq, Debug)

///|
/// Result of a write.
///
/// `Unknown` is not an error and must not be retried blindly: the write may
/// or may not have landed. The caller re-reads and reconciles. Collapsing it
/// into failure is how a WAL corrupts itself.
pub(all) enum PutOutcome {
  /// The write landed. Carries the new version tag.
  Applied(String)
  /// The precondition did not hold. The store is unchanged; re-read and retry.
  NotApplied
  /// Indeterminate (timeout, 5xx). State must be reconciled by reading.
  Unknown
} derive(Eq, Debug)

///|
/// Result of a read.
pub(all) enum GetOutcome {
  /// Body plus the version tag it was read at.
  Found(Bytes, String)
  /// The caller's `if_none_match` version is still current (HTTP 304).
  NotModified
  /// No such key.
  Missing
} derive(Eq, Debug)

///|
/// One entry in a listing.
pub(all) struct ObjEntry {
  key : String
  size : Int64
  etag : String
} derive(Eq, Debug)

///|
/// A page of a listing. `next` carries the continuation token when the store
/// truncated the result.
pub(all) struct ObjListing {
  entries : Array[ObjEntry]
  next : String?
} derive(Eq, Debug)

///|
/// Inclusive byte range, matching HTTP `Range: bytes=<start>-<end>`.
pub(all) struct ByteRange {
  start : Int64
  end : Int64
} derive(Eq, Debug)

///|
/// Extract the body of a successful read, raising when the key is absent.
///
/// Convenience for call sites that have already established the key must
/// exist; `Missing` there means the store is corrupt, not that the caller
/// should branch.
pub fn GetOutcome::unwrap(
  self : GetOutcome,
  key : String,
) -> (Bytes, String) raise @bit.GitError {
  match self {
    Found(body, etag) => (body, etag)
    NotModified => raise @bit.GitError::IoError("unexpected 304 for \{key}")
    Missing => raise @bit.GitError::IoError("object not found: \{key}")
  }
}

///|
/// Whether a write landed.
pub fn PutOutcome::is_applied(self : PutOutcome) -> Bool {
  match self {
    Applied(_) => true
    _ => false
  }
}

///|
pub impl Show for PutCondition with fn output(self, logger) {
  match self {
    Unconditional => logger.write_string("Unconditional")
    IfNotExists => logger.write_string("IfNotExists")
    IfMatch(etag) => logger.write_string("IfMatch(\{etag})")
  }
}

///|
pub impl Show for PutOutcome with fn output(self, logger) {
  match self {
    Applied(etag) => logger.write_string("Applied(\{etag})")
    NotApplied => logger.write_string("NotApplied")
    Unknown => logger.write_string("Unknown")
  }
}

///|
/// Bodies are shown by length, not content: a `GetOutcome` in a failing test
/// is usually a whole pack.
pub impl Show for GetOutcome with fn output(self, logger) {
  match self {
    Found(body, etag) =>
      logger.write_string("Found(\{body.length()} bytes, \{etag})")
    NotModified => logger.write_string("NotModified")
    Missing => logger.write_string("Missing")
  }
}
