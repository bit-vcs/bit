///| SyncLink: tracks bit <-> GitHub issue/PR mappings

///|
/// Tracks the mapping between a local bit work item and a remote GitHub issue/PR
pub struct SyncLink {
  local_id : String
  local_kind : String // "issue" or "pr"
  provider : String // "github"
  repo : String // "owner/repo"
  remote_number : Int
  remote_node_id : String
  last_pull_at : Int64
  last_push_at : Int64
  remote_updated_at : Int64
}

///|
pub fn SyncLink::new(
  local_id : String,
  local_kind : String,
  provider : String,
  repo : String,
  remote_number? : Int = 0,
  remote_node_id? : String = "",
  last_pull_at? : Int64 = 0L,
  last_push_at? : Int64 = 0L,
  remote_updated_at? : Int64 = 0L,
) -> SyncLink {
  {
    local_id,
    local_kind,
    provider,
    repo,
    remote_number,
    remote_node_id,
    last_pull_at,
    last_push_at,
    remote_updated_at,
  }
}

///|
pub fn SyncLink::local_id(self : SyncLink) -> String {
  self.local_id
}

///|
pub fn SyncLink::local_kind(self : SyncLink) -> String {
  self.local_kind
}

///|
pub fn SyncLink::provider(self : SyncLink) -> String {
  self.provider
}

///|
pub fn SyncLink::repo(self : SyncLink) -> String {
  self.repo
}

///|
pub fn SyncLink::remote_number(self : SyncLink) -> Int {
  self.remote_number
}

///|
pub fn SyncLink::remote_node_id(self : SyncLink) -> String {
  self.remote_node_id
}

///|
pub fn SyncLink::last_pull_at(self : SyncLink) -> Int64 {
  self.last_pull_at
}

///|
pub fn SyncLink::last_push_at(self : SyncLink) -> Int64 {
  self.last_push_at
}

///|
pub fn SyncLink::remote_updated_at(self : SyncLink) -> Int64 {
  self.remote_updated_at
}

///|
/// Serialize SyncLink to Git-style text format
pub fn SyncLink::serialize(self : SyncLink) -> String {
  let sb = StringBuilder::new()
  sb.write_string("sync-link ")
  sb.write_string(self.local_id)
  sb.write_char('\n')
  sb.write_string("local-kind ")
  sb.write_string(self.local_kind)
  sb.write_char('\n')
  sb.write_string("provider ")
  sb.write_string(self.provider)
  sb.write_char('\n')
  sb.write_string("repo ")
  sb.write_string(self.repo)
  sb.write_char('\n')
  sb.write_string("remote-number ")
  sb.write_string(self.remote_number.to_string())
  sb.write_char('\n')
  sb.write_string("remote-node-id ")
  sb.write_string(self.remote_node_id)
  sb.write_char('\n')
  sb.write_string("last-pull-at ")
  sb.write_string(self.last_pull_at.to_string())
  sb.write_char('\n')
  sb.write_string("last-push-at ")
  sb.write_string(self.last_push_at.to_string())
  sb.write_char('\n')
  sb.write_string("remote-updated-at ")
  sb.write_string(self.remote_updated_at.to_string())
  sb.write_char('\n')
  sb.to_string()
}

///|
/// Parse SyncLink from Git-style text format
pub fn parse_sync_link(text : String) -> SyncLink raise PrError {
  let mut local_id = ""
  let mut local_kind = ""
  let mut provider = ""
  let mut repo = ""
  let mut remote_number = 0
  let mut remote_node_id = ""
  let mut last_pull_at : Int64 = 0
  let mut last_push_at : Int64 = 0
  let mut remote_updated_at : Int64 = 0
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if line.length() == 0 {
      continue
    }
    let space = line.find(" ")
    match space {
      None => continue
      Some(idx) => {
        let key = String::unsafe_substring(line, start=0, end=idx)
        let value = String::unsafe_substring(
          line,
          start=idx + 1,
          end=line.length(),
        )
        match key {
          "sync-link" => local_id = value
          "local-kind" => local_kind = value
          "provider" => provider = value
          "repo" => repo = value
          "remote-number" => remote_number = parse_int(value)
          "remote-node-id" => remote_node_id = value
          "last-pull-at" => last_pull_at = parse_int64(value)
          "last-push-at" => last_push_at = parse_int64(value)
          "remote-updated-at" => remote_updated_at = parse_int64(value)
          _ => ()
        }
      }
    }
  }
  if local_id.length() == 0 {
    raise PrError::InvalidFormat("Missing sync-link id")
  }
  SyncLink::new(
    local_id,
    local_kind,
    provider,
    repo,
    remote_number~,
    remote_node_id~,
    last_pull_at~,
    last_push_at~,
    remote_updated_at~,
  )
}
