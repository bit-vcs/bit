///| WASM Component push HTTP exchange helpers

///|
fn net_execute_push_request(
  remote_url : String,
  refname : String,
  head_id : @bit.ObjectId,
  pack : Bytes,
  http_get : (String, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
  http_post : (String, Bytes, Map[String, String]) -> (@bit.HttpResponse, Bytes) raise @bit.GitError,
) -> String raise @bit.GitError {
  let (info_url, headers) = receive_pack_info_refs_request(remote_url)
  let (response, data) = http_get(info_url, headers)
  if response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to discover refs: HTTP \{response.code}",
    )
  }
  let old_id = receive_pack_parse_advertisement(data, refname)
  let (push_url, body, push_headers) = receive_pack_service_request(
    remote_url, head_id, old_id, refname, pack,
  )
  let (push_response, push_data) = http_post(push_url, body, push_headers)
  if push_response.code != 200 {
    raise @bit.GitError::ProtocolError(
      "Failed to push: HTTP \{push_response.code}",
    )
  }
  receive_pack_parse_result(push_data)
}
