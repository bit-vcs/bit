///| WASM Component network remote helpers

///|
fn net_normalize_remote_for_http_transport(
  remote : String,
) -> String raise @bit.GitError {
  let spec = @protocol.parse_remote(remote)
  match spec.kind {
    @protocol.RemoteKind::Http => remote
    @protocol.RemoteKind::Ssh =>
      match @protocol.ssh_remote_to_https(remote) {
        Some(url) => url
        None => raise @bit.GitError::ProtocolError("HTTP transport required")
      }
    @protocol.RemoteKind::File =>
      raise @bit.GitError::ProtocolError("HTTP transport required")
  }
}

///|
fn net_http_remote(remote : String) -> @protocol.Remote raise @bit.GitError {
  @protocol.Remote::new(net_normalize_remote_for_http_transport(remote))
}
