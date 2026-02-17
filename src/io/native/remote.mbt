///| Git HTTP push protocol - native implementation

///| This file is only compiled for native target

///|
/// Fetch receive-pack refs via smart HTTP (native)
pub async fn discover_receive_refs_http(
  remote : @protocol.Remote,
) -> Array[(@bit.ObjectId, String)] raise @bit.GitError {
  let (refs, _) = @protocol.discover_refs_with_http(remote, native_http_get)
  refs
}

///|
/// Discover refs and capabilities from remote (native)
pub async fn discover_refs(
  remote : @protocol.Remote,
) -> (Array[(@bit.ObjectId, String)], Array[String]) raise @bit.GitError {
  @protocol.discover_refs_with_http(remote, native_http_get)
}

///|
/// Push a packfile to remote repository (native)
pub async fn push(
  remote : @protocol.Remote,
  req : @protocol.PushRequest,
) -> String raise @bit.GitError {
  @protocol.push_with_http(remote, req, native_http_get, native_http_post)
}

///|
/// Push a single file as a new commit (native)
pub async fn push_file(
  remote : @protocol.Remote,
  content : Bytes,
  filename : String,
  message : String,
  author : String,
  timestamp : Int64,
  parent : @bit.ObjectId?,
) -> @bit.ObjectId raise @bit.GitError {
  let parents = match parent {
    Some(p) => [p]
    None => []
  }
  let commit = @bit.Commit::new(
    @bit.ObjectId::zero(),
    parents,
    author,
    timestamp,
    "+0000",
    author,
    timestamp,
    "+0000",
    message,
  )
  let (commit_id, packfile) = @pack.create_commit_packfile(
    content, filename, commit,
  )
  let old_id = match parent {
    Some(p) => p
    None => @bit.ObjectId::zero()
  }
  let req = @protocol.PushRequest::new(
    old_id, commit_id, "refs/heads/main", packfile,
  )
  let _ = push(remote, req)
  commit_id
}
