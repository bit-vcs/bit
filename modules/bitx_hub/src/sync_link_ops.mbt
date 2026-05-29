///| SyncLink CRUD operations on Hub

///|
/// Store a SyncLink as a hub record
pub fn Hub::put_sync_link(
  self : Hub,
  objects : &@lib.ObjectStore,
  refs : &@lib.RefStore,
  clock : &@lib.Clock,
  link : SyncLink,
) -> Unit raise @bit.GitError {
  let key = sync_link_key(link.local_id, link.provider)
  ignore(
    self.store.put_record(
      objects,
      refs,
      clock,
      key,
      sync_link_record_kind(),
      link.serialize(),
      self.store.node_id(),
    ),
  )
}

///|
/// Retrieve a SyncLink by local_id and provider
pub fn Hub::get_sync_link(
  self : Hub,
  objects : &@lib.ObjectStore,
  local_id : String,
  provider : String,
) -> SyncLink? {
  let key = sync_link_key(local_id, provider)
  let record = self.store.get_record(objects, key)
  match record {
    None => None
    Some(r) => {
      let link = parse_sync_link(r.payload) catch { _ => return None }
      Some(link)
    }
  }
}

///|
/// List all SyncLinks, optionally filtered by repo
pub fn Hub::list_sync_links(
  self : Hub,
  objects : &@lib.ObjectStore,
  repo? : String = "",
) -> Array[SyncLink] {
  let records = self.store.list_records(objects, "hub/sync-link/")
  let result : Array[SyncLink] = []
  for record in records {
    if !is_sync_link_record_kind(record.kind) {
      continue
    }
    let link = parse_sync_link(record.payload) catch { _ => continue }
    if repo.length() > 0 && link.repo != repo {
      continue
    }
    result.push(link)
  }
  result
}

///|
/// Find a SyncLink by provider, repo, and remote number
pub fn Hub::find_sync_link_by_remote(
  self : Hub,
  objects : &@lib.ObjectStore,
  provider : String,
  repo : String,
  remote_number : Int,
) -> SyncLink? {
  let all = self.list_sync_links(objects)
  for link in all {
    if link.provider == provider &&
      link.repo == repo &&
      link.remote_number == remote_number {
      return Some(link)
    }
  }
  None
}
