///| Upload-pack over HTTP - common logic (all targets)

///| Uses HTTP client functions passed as arguments

///|
pub async fn upload_pack_info_refs_with_http(
  remote : String,
  prefer_v2 : Bool,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  let normalized_remote = normalize_remote_for_http_transport(remote)
  let spec = parse_remote(normalized_remote)
  if spec.kind != RemoteKind::Http {
    raise @bit.GitError::ProtocolError("HTTP transport required")
  }
  let base = spec.base_url.unwrap_or(normalized_remote)
  let url = "\{base}/info/refs?service=git-upload-pack"
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Accept": "application/x-git-upload-pack-advertisement",
  }
  if prefer_v2 {
    headers.set("Git-Protocol", "version=2")
  }
  let (response, data) = http_get(url, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to fetch info/refs: HTTP \{response.code}",
    )
  }
  data
}

///|
pub async fn upload_pack_request_with_http(
  remote : String,
  body : Bytes,
  prefer_v2 : Bool,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  let normalized_remote = normalize_remote_for_http_transport(remote)
  let spec = parse_remote(normalized_remote)
  if spec.kind != RemoteKind::Http {
    raise @bit.GitError::ProtocolError("HTTP transport required")
  }
  let base = spec.base_url.unwrap_or(normalized_remote)
  let url = "\{base}/git-upload-pack"
  let headers : Map[String, String] = {
    "User-Agent": "git/moonbit",
    "Content-Type": "application/x-git-upload-pack-request",
    "Accept": "application/x-git-upload-pack-result",
  }
  if prefer_v2 {
    headers.set("Git-Protocol", "version=2")
  }
  let (response, data) = http_post(url, body, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to upload-pack: HTTP \{response.code}",
    )
  }
  data
}

///|
pub async fn discover_upload_refs_with_http(
  remote : String,
  prefer_v2 : Bool,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> (
  Array[(@bit.ObjectId, String)],
  Array[String],
  ProtocolVersion,
  Map[String, String],
) raise @bit.GitError {
  let adv = upload_pack_info_refs_with_http(remote, prefer_v2, http_get)
  let version = detect_protocol_version(adv)
  if version == ProtocolVersion::V2 {
    let caps = parse_v2_advertised_caps(adv)
    let req = build_ls_refs_request("git/moonbit", [
      "refs/heads/", "refs/tags/", "HEAD",
    ])
    let resp = upload_pack_request_with_http(remote, req, true, http_post)
    let parsed = parse_ls_refs_response(resp)
    return (parsed.refs, caps, version, parsed.symrefs)
  }
  let refs = parse_refs(adv)
  let caps = extract_capabilities(adv)
  let symrefs = parse_symrefs_from_capabilities(caps)
  (refs, caps, ProtocolVersion::V0, symrefs)
}

///|
fn normalize_remote_for_http_transport(
  remote : String,
) -> String raise @bit.GitError {
  let spec = parse_remote(remote)
  match spec.kind {
    RemoteKind::Http => remote
    RemoteKind::Ssh =>
      match ssh_remote_to_https(remote) {
        Some(url) => url
        None => raise @bit.GitError::ProtocolError("HTTP transport required")
      }
    RemoteKind::File =>
      raise @bit.GitError::ProtocolError("HTTP transport required")
  }
}

///|
pub async fn fetch_pack_with_http(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
  depth : Int,
  filter : FilterSpec,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Bytes raise @bit.GitError {
  let (refs, caps, version, _symrefs) = discover_upload_refs_with_http(
    remote, prefer_v2, http_get, http_post,
  )
  let wants = if wants.length() == 0 {
    let ids : Array[@bit.ObjectId] = []
    for item in refs {
      let (id, _) = item
      ids.push(id)
    }
    ids
  } else {
    wants
  }
  if version == ProtocolVersion::V2 {
    let req = build_fetch_request_v2("git/moonbit", wants, depth, filter~)
    let resp = upload_pack_request_with_http(remote, req, true, http_post)
    return extract_pack_from_v2_response(resp)
  }
  let req = build_fetch_request_v0("git/moonbit", wants, caps)
  let resp = upload_pack_request_with_http(remote, req, false, http_post)
  extract_pack_from_v0_response(resp)
}

///|
pub async fn fetch_objects_with_http(
  remote : String,
  wants : Array[@bit.ObjectId],
  prefer_v2 : Bool,
  depth : Int,
  filter : FilterSpec,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> Array[@bit.PackObject] raise @bit.GitError {
  let pack = fetch_pack_with_http(
    remote, wants, prefer_v2, depth, filter, http_get, http_post,
  )
  @pack.parse_packfile(pack)
}

///|
pub async fn clone_with_http(
  remote : String,
  prefer_v2 : Bool,
  depth : Int,
  filter : FilterSpec,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
) -> (Array[(@bit.ObjectId, String)], Array[@bit.PackObject]) raise @bit.GitError {
  let (refs, _caps, _version, symrefs) = discover_upload_refs_with_http(
    remote, prefer_v2, http_get, http_post,
  )
  let wants = select_default_wants(refs, symrefs)
  let pack = fetch_pack_with_http(
    remote, wants, prefer_v2, depth, filter, http_get, http_post,
  )
  let objects = @pack.parse_packfile(pack)
  (refs, objects)
}

///|
pub async fn clone_to_fs_with_http(
  remote : String,
  prefer_v2 : Bool,
  depth : Int,
  filter : FilterSpec,
  fs : &@bit.FileSystem,
  root : String,
  http_get : async (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : async (String, Bytes, Map[String, String]) -> (
    @bit.HttpResponse,
    Bytes,
  ) raise @bit.GitError,
  no_checkout? : Bool = false,
) -> Array[(@bit.ObjectId, String)] raise @bit.GitError {
  let (refs, _caps, _version, symrefs) = discover_upload_refs_with_http(
    remote, prefer_v2, http_get, http_post,
  )
  let wants = select_default_wants(refs, symrefs)
  let default_ref = select_default_ref(refs, symrefs)
  match default_ref {
    None => return refs
    Some(_) => ()
  }
  if wants.length() == 0 {
    return refs
  }
  let objects = {
    let pack = fetch_pack_with_http(
      remote, wants, prefer_v2, depth, filter, http_get, http_post,
    )
    let pack_id = read_pack_trailer_id_http(pack)
    let objects = @pack.parse_packfile(pack)
    match default_ref {
      Some(_) => {
        let git_dir = @bit.join_path(root, ".git")
        fs.mkdir_p(@bit.join_path(git_dir, "objects/pack"))
        @pack.write_packfile_with_index(fs, git_dir, pack, objects)
        if filter.is_partial() {
          write_promisor_file(fs, git_dir, remote)
          write_pack_promisor_marker_http(
            fs, git_dir, pack_id, refs, default_ref,
          )
        }
      }
      None => ()
    }
    objects
  }
  if filter.is_partial() {
    match default_ref {
      Some((refname, commit_id)) => {
        let git_dir = @bit.join_path(root, ".git")
        write_partial_clone_refs(
          fs, git_dir, refname, commit_id, remote, filter,
        )
      }
      None => ()
    }
  } else {
    let store = @bit.ObjectStore::from_pack(objects)
    match default_ref {
      None => ()
      Some((refname, commit_id)) =>
        if no_checkout {
          @bit.write_git_metadata(store, commit_id, refname, remote, fs, root)
        } else {
          @bit.materialize_clone_to_fs(
            store, commit_id, refname, remote, fs, root,
          )
        }
    }
  }
  refs
}

///|
fn write_promisor_file(
  fs : &@bit.FileSystem,
  git_dir : String,
  remote : String,
) -> Unit raise @bit.GitError {
  let promisor_dir = @bit.join_path(git_dir, "objects/info")
  fs.mkdir_p(promisor_dir)
  let promisor_path = @bit.join_path(promisor_dir, "promisor")
  fs.write_string(promisor_path, remote + "\n")
}

///|
fn read_pack_trailer_id_http(pack : Bytes) -> @bit.ObjectId raise @bit.GitError {
  if pack.length() < 20 {
    raise @bit.GitError::PackfileError("Packfile too short")
  }
  let trailer_start = pack.length() - 20
  let bytes = FixedArray::makei(20, i => pack[trailer_start + i])
  @bit.ObjectId::new(bytes)
}

///|
fn write_pack_promisor_marker_http(
  fs : &@bit.FileSystem,
  git_dir : String,
  pack_id : @bit.ObjectId,
  refs : Array[(@bit.ObjectId, String)],
  default_ref : (String, @bit.ObjectId)?,
) -> Unit raise @bit.GitError {
  let pack_dir = @bit.join_path(git_dir, "objects/pack")
  fs.mkdir_p(pack_dir)
  let marker_lines : Array[String] = []
  let seen : Map[String, Bool] = {}
  for item in refs {
    let (id, name) = item
    if name.length() == 0 {
      continue
    }
    let line = id.to_hex() + " " + name
    if seen.contains(line) {
      continue
    }
    seen[line] = true
    marker_lines.push(line)
  }
  match default_ref {
    Some((_, head_id)) => {
      let head_line = head_id.to_hex() + " HEAD"
      if !seen.contains(head_line) {
        seen[head_line] = true
        marker_lines.push(head_line)
      }
    }
    None => ()
  }
  if marker_lines.length() == 0 {
    return ()
  }
  let marker_content = marker_lines.join("\n") + "\n"
  let base = "pack-\{pack_id.to_hex()}"
  let marker_path = @bit.join_path(pack_dir, base + ".promisor")
  fs.write_string(marker_path, marker_content)
}

///|
fn write_partial_clone_refs(
  fs : &@bit.FileSystem,
  git_dir : String,
  refname : String,
  commit_id : @bit.ObjectId,
  remote : String,
  filter : FilterSpec,
) -> Unit raise @bit.GitError {
  let head_path = @bit.join_path(git_dir, "HEAD")
  if refname == "HEAD" {
    fs.write_string(head_path, commit_id.to_hex() + "\n")
  } else {
    fs.write_string(head_path, "ref: \{refname}\n")
    let ref_path = @bit.join_path(git_dir, refname)
    let ref_dir = {
      let mut last_slash = -1
      for i, c in ref_path {
        if c == '/' {
          last_slash = i
        }
      }
      if last_slash > 0 {
        String::unsafe_substring(ref_path, start=0, end=last_slash)
      } else {
        git_dir
      }
    }
    fs.mkdir_p(ref_dir)
    fs.write_string(ref_path, commit_id.to_hex() + "\n")
  }
  let config_path = @bit.join_path(git_dir, "config")
  let config = "[core]\n\trepositoryformatversion = 1\n\tfilemode = true\n\tbare = false\n\tlogallaliases = false\n[extensions]\n\tpartialclone = origin\n[remote \"origin\"]\n\turl = \{remote}\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n\tpromisor = true\n\tpartialclonefilter = \{filter.to_string()}\n"
  fs.write_string(config_path, config)
}
