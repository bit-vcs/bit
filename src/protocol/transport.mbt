///| Transport utilities (remote parsing)

///|
pub(all) enum RemoteKind {
  Http
  Ssh
  File
} derive(Eq)

///|
pub struct RemoteSpec {
  kind : RemoteKind
  raw : String
  host : String?
  path : String
  base_url : String?
}

///|
pub fn parse_remote(remote : String) -> RemoteSpec {
  if remote.has_prefix("http://") || remote.has_prefix("https://") {
    let base = normalize_http_url(remote)
    return {
      kind: RemoteKind::Http,
      raw: remote,
      host: None,
      path: "",
      base_url: Some(base),
    }
  }
  if remote.has_prefix("ssh://") {
    return parse_ssh_url(remote)
  }
  if remote.has_prefix("file://") {
    let path = String::unsafe_substring(remote, start=7, end=remote.length())
    return {
      kind: RemoteKind::File,
      raw: remote,
      host: None,
      path,
      base_url: None,
    }
  }
  if remote.has_prefix("[") {
    match remote.find("]:") {
      Some(idx) => {
        let host = String::unsafe_substring(remote, start=1, end=idx)
        let path = String::unsafe_substring(
          remote,
          start=idx + 2,
          end=remote.length(),
        )
        if host.length() > 0 && path.length() > 0 && !host.contains("/") {
          return {
            kind: RemoteKind::Ssh,
            raw: remote,
            host: Some(host),
            path,
            base_url: None,
          }
        }
      }
      None => ()
    }
  }
  // scp-style: [user@]host:path
  let colon = remote.find(":")
  if colon is Some(idx) && !remote.has_prefix("/") {
    let host = String::unsafe_substring(remote, start=0, end=idx)
    let path = String::unsafe_substring(
      remote,
      start=idx + 1,
      end=remote.length(),
    )
    if host.length() > 0 && path.length() > 0 && !host.contains("/") {
      return {
        kind: RemoteKind::Ssh,
        raw: remote,
        host: Some(host),
        path,
        base_url: None,
      }
    }
  }
  // default: local path
  {
    kind: RemoteKind::File,
    raw: remote,
    host: None,
    path: remote,
    base_url: None,
  }
}

///|
/// Convert SSH-style remote URL into HTTPS smart transport URL.
/// Returns None for non-SSH remotes.
pub fn ssh_remote_to_https(remote : String) -> String? {
  let spec = parse_remote(remote)
  if spec.kind != RemoteKind::Ssh {
    return None
  }
  guard spec.host is Some(raw_host) else { return None }
  let host = normalize_ssh_host_for_https(raw_host)
  let path = normalize_ssh_path_for_https(spec.path)
  if host.length() == 0 || path.length() == 0 {
    return None
  }
  Some("https://" + host + "/" + path)
}

///|
fn normalize_http_url(url : String) -> String {
  if url.has_suffix(".git") {
    String::unsafe_substring(url, start=0, end=url.length() - 4)
  } else {
    url
  }
}

///|
fn normalize_ssh_host_for_https(raw_host : String) -> String {
  let host_with_port = match raw_host.rev_find("@") {
    Some(idx) =>
      String::unsafe_substring(raw_host, start=idx + 1, end=raw_host.length())
    None => raw_host
  }
  if host_with_port.has_prefix("[") {
    match host_with_port.find("]") {
      Some(idx) => String::unsafe_substring(host_with_port, start=1, end=idx)
      None => host_with_port
    }
  } else {
    match host_with_port.find(":") {
      Some(idx) => String::unsafe_substring(host_with_port, start=0, end=idx)
      None => host_with_port
    }
  }
}

///|
fn normalize_ssh_path_for_https(raw_path : String) -> String {
  let mut start = 0
  while start < raw_path.length() && raw_path[start] == '/' {
    start += 1
  }
  String::unsafe_substring(raw_path, start~, end=raw_path.length())
}

///|
fn parse_ssh_url(remote : String) -> RemoteSpec {
  // ssh://[user@]host[:port]/path
  let rest = String::unsafe_substring(remote, start=6, end=remote.length())
  let slash = rest.find("/")
  match slash {
    None =>
      {
        kind: RemoteKind::Ssh,
        raw: remote,
        host: Some(rest),
        path: "",
        base_url: None,
      }
    Some(idx) => {
      let authority = String::unsafe_substring(rest, start=0, end=idx)
      let host = if authority.has_suffix(":") {
        String::unsafe_substring(authority, start=0, end=authority.length() - 1)
      } else {
        authority
      }
      let path = "/" +
        String::unsafe_substring(rest, start=idx + 1, end=rest.length())
      {
        kind: RemoteKind::Ssh,
        raw: remote,
        host: Some(host),
        path,
        base_url: None,
      }
    }
  }
}
