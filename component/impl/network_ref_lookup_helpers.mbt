///| WASM Component network ref lookup helpers

///|
fn net_parse_symrefs_from_capabilities(
  caps : Array[String],
) -> Map[String, String] {
  let symrefs : Map[String, String] = {}
  for cap in caps {
    if cap.has_prefix("symref=") {
      let raw = String::unsafe_substring(cap, start=7, end=cap.length())
      match raw.find(":") {
        None => ()
        Some(idx) => {
          let source = String::unsafe_substring(raw, start=0, end=idx)
          let target = String::unsafe_substring(
            raw,
            start=idx + 1,
            end=raw.length(),
          )
          symrefs[source] = target
        }
      }
      continue
    }
    if cap.has_prefix("symref-target:") {
      let target = String::unsafe_substring(cap, start=14, end=cap.length())
      symrefs["HEAD"] = target
      continue
    }
  }
  symrefs
}

///|
fn net_find_ref(
  refs : Array[(@bit.ObjectId, String)],
  name : String,
) -> @bit.ObjectId {
  for item in refs {
    let (id, refname) = item
    if refname == name {
      return id
    }
  }
  @bit.ObjectId::zero()
}
