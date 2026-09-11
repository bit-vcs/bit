///|
/// The storage contract every backend implements.
///
/// Async-only by design. Every real backend (S3, R2, GCS) is async, and an
/// in-memory or on-disk backend satisfies an async method with a body that
/// never suspends — so one trait keeps callers on a single code path rather
/// than forcing a sync and an async copy of everything above it.
pub(open) trait ObjectStore {
  /// Read a whole object.
  async fn get(Self, String) -> GetOutcome raise @bit.GitError
  /// Read a byte range. Backends that cannot serve ranges must still return
  /// the requested slice, reading more than they need if necessary.
  async fn get_range(Self, String, ByteRange) -> GetOutcome raise @bit.GitError
  /// Conditional read. Returns `NotModified` when the caller's version tag is
  /// still current, which is how a replica cheaply checks the manifest.
  async fn get_if_none_match(Self, String, String) -> GetOutcome raise @bit.GitError
  /// Write, subject to a precondition.
  async fn put(Self, String, Bytes, PutCondition) -> PutOutcome raise @bit.GitError
  /// Remove a key. Deleting an absent key succeeds.
  async fn delete(Self, String) -> Unit raise @bit.GitError
  /// List one page of keys under a prefix, starting after the given key
  /// (empty string for the first page).
  async fn list(Self, String, String) -> ObjListing raise @bit.GitError
  /// Whether this backend enforces write preconditions. A store that answers
  /// `false` cannot host a WAL: its CAS would silently degrade to a
  /// last-writer-wins overwrite.
  fn supports_cas(Self) -> Bool
}

///|
/// Read every page of a listing under `prefix`.
///
/// Callers that need the whole key set (a checkpoint fold, a GC sweep) should
/// use this rather than paging by hand.
pub async fn[S : ObjectStore] list_all(
  store : S,
  prefix : String,
) -> Array[ObjEntry] raise @bit.GitError {
  let out : Array[ObjEntry] = []
  let mut after = ""
  for _ in 0..<MAX_LIST_PAGES {
    let page = store.list(prefix, after)
    for entry in page.entries {
      out.push(entry)
    }
    match page.next {
      Some(token) => after = token
      None => return out
    }
  }
  raise @bit.GitError::IoError(
    "listing \{prefix} exceeded \{MAX_LIST_PAGES} pages",
  )
}

///|
/// Bound on `list_all` so a store that keeps handing back continuation tokens
/// fails loudly instead of looping forever.
const MAX_LIST_PAGES : Int = 10000

///|
/// Write a content-addressed object, treating "already there" as success.
///
/// Packs and snapshots are named by their own hash, so a create-only PUT that
/// loses the race wrote identical bytes. This is what makes the pre-CAS steps
/// of a push safe to repeat after an `Unknown`.
pub async fn[S : ObjectStore] put_immutable(
  store : S,
  key : String,
  body : Bytes,
) -> PutOutcome raise @bit.GitError {
  match store.put(key, body, PutCondition::IfNotExists) {
    // Someone else wrote the same content-addressed bytes first.
    NotApplied => PutOutcome::Applied("")
    other => other
  }
}
