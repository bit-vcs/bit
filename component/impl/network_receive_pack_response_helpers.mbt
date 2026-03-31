///| WASM Component receive-pack response helpers

///|
fn receive_pack_parse_advertisement(
  data : Bytes,
  refname : String,
) -> @bit.ObjectId raise @bit.GitError {
  let refs = @protocol.parse_refs(data)
  net_find_ref(refs, refname)
}

///|
fn receive_pack_parse_result(data : Bytes) -> String raise @bit.GitError {
  match @protocol.parse_receive_pack_response(data) {
    Ok(msg) => msg
    Err(err) => raise err
  }
}
