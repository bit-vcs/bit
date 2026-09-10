///|
/// Minimal reader for the one XML document this module has to understand:
/// the `ListObjectsV2` response.
///
/// A general XML parser would be a lot of surface area for a document whose
/// shape is fixed by the S3 API, so this walks tags directly. Anything it
/// does not recognise is ignored rather than guessed at.

///|
/// Text between the first `<tag>` and its matching `</tag>`, searching from
/// `from`. Returns the text and the index just past the closing tag.
fn xml_take(body : String, tag : String, from : Int) -> (String, Int)? {
  let open_tag = "<\{tag}>"
  let close_tag = "</\{tag}>"
  let rest = String::unsafe_substring(body, start=from, end=body.length())
  let open_at = match rest.find(open_tag) {
    Some(i) => from + i
    None => return None
  }
  let value_start = open_at + open_tag.length()
  let tail = String::unsafe_substring(
    body,
    start=value_start,
    end=body.length(),
  )
  let close_at = match tail.find(close_tag) {
    Some(i) => value_start + i
    None => return None
  }
  let value = String::unsafe_substring(body, start=value_start, end=close_at)
  Some((value, close_at + close_tag.length()))
}

///|
/// Decode the five XML entities S3 uses when escaping keys.
///
/// Runs between entities are copied as substrings rather than code unit by
/// code unit, so a key containing astral characters keeps its surrogate pairs
/// intact.
pub fn xml_unescape(value : String) -> String {
  if value.find("&") is None {
    return value
  }
  let out = StringBuilder::new()
  let n = value.length()
  let mut run_start = 0
  let mut i = 0
  while i < n {
    if value[i] != '&' {
      i += 1
      continue
    }
    let rest = String::unsafe_substring(value, start=i, end=n)
    let decoded = if rest.has_prefix("&amp;") {
      Some(("&", 5))
    } else if rest.has_prefix("&lt;") {
      Some(("<", 4))
    } else if rest.has_prefix("&gt;") {
      Some((">", 4))
    } else if rest.has_prefix("&quot;") {
      Some(("\"", 6))
    } else if rest.has_prefix("&apos;") {
      Some(("'", 6))
    } else {
      None
    }
    match decoded {
      Some((text, width)) => {
        out.write_string(
          String::unsafe_substring(value, start=run_start, end=i),
        )
        out.write_string(text)
        i += width
        run_start = i
      }
      // A bare `&` is not an entity we know; leave it as written.
      None => i += 1
    }
  }
  out.write_string(String::unsafe_substring(value, start=run_start, end=n))
  out.to_string()
}

///|
fn parse_int64(value : String) -> Int64 {
  let mut acc = 0L
  for c in value {
    let d = c.to_int() - 48
    if d < 0 || d > 9 {
      return acc
    }
    acc = acc * 10L + d.to_int64()
  }
  acc
}

///|
/// Parse a `ListObjectsV2` response body.
///
/// Pagination is expressed as `start-after` rather than a continuation token,
/// so a truncated page reports its last key as the cursor. That keeps the
/// `ObjectStore` contract to one string and works identically on stores whose
/// continuation tokens are opaque.
pub fn parse_list_objects_v2(body : String) -> ObjListing {
  let entries : Array[ObjEntry] = []
  let mut cursor = 0
  while true {
    match xml_take(body, "Contents", cursor) {
      Some((block, next)) => {
        cursor = next
        let key = match xml_take(block, "Key", 0) {
          Some((value, _)) => xml_unescape(value)
          None => continue
        }
        let size = match xml_take(block, "Size", 0) {
          Some((value, _)) => parse_int64(value)
          None => 0L
        }
        let etag = match xml_take(block, "ETag", 0) {
          Some((value, _)) => strip_etag_quotes(xml_unescape(value))
          None => ""
        }
        entries.push({ key, size, etag })
      }
      None => break
    }
  }
  let truncated = match xml_take(body, "IsTruncated", 0) {
    Some((value, _)) => value == "true"
    None => false
  }
  let next = if truncated && entries.length() > 0 {
    Some(entries[entries.length() - 1].key)
  } else {
    None
  }
  { entries, next }
}
