///| JS transport registry bridge for injected HTTP transports.

///|
fn js_transport_bytes_to_array(bytes : Bytes) -> Array[Byte] {
  let out : Array[Byte] = Array::new(capacity=bytes.length())
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
  out
}

///|
fn js_transport_headers_to_arrays(
  headers : Map[String, String],
) -> (Array[String], Array[String]) {
  let names : Array[String] = []
  let values : Array[String] = []
  for entry in headers.to_array() {
    let (name, value) = entry
    names.push(name)
    values.push(value)
  }
  (names, values)
}

///|
fn js_transport_b64_decode_char(c : Char) -> Int {
  if c >= 'A' && c <= 'Z' {
    c.to_int() - 'A'.to_int()
  } else if c >= 'a' && c <= 'z' {
    c.to_int() - 'a'.to_int() + 26
  } else if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int() + 52
  } else if c == '+' {
    62
  } else if c == '/' {
    63
  } else {
    -1
  }
}

///|
fn js_transport_base64_decode(b64 : String) -> Bytes {
  let out : Array[Byte] = []
  let chars : Array[Int] = []
  for c in b64 {
    if c == '=' {
      break
    }
    let v = js_transport_b64_decode_char(c)
    if v >= 0 {
      chars.push(v)
    }
  }
  let mut i = 0
  while i + 1 < chars.length() {
    if i + 3 < chars.length() {
      let n = (chars[i] << 18) |
        (chars[i + 1] << 12) |
        (chars[i + 2] << 6) |
        chars[i + 3]
      out.push(((n >> 16) & 0xff).to_byte())
      out.push(((n >> 8) & 0xff).to_byte())
      out.push((n & 0xff).to_byte())
      i += 4
    } else if i + 2 < chars.length() {
      let n = (chars[i] << 18) | (chars[i + 1] << 12) | (chars[i + 2] << 6)
      out.push(((n >> 16) & 0xff).to_byte())
      out.push(((n >> 8) & 0xff).to_byte())
      i += 3
    } else {
      let n = (chars[i] << 18) | (chars[i + 1] << 12)
      out.push(((n >> 16) & 0xff).to_byte())
      i += 2
    }
  }
  Bytes::from_array(FixedArray::makei(out.length(), fn(idx) { out[idx] }))
}

///|
fn js_transport_parse_response(
  raw : String,
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  guard raw.find("\n") is Some(split) else {
    raise @bit.GitError::ProtocolError("Malformed JS transport response")
  }
  let status_raw = String::unsafe_substring(raw, start=0, end=split)
  let body_b64 = String::unsafe_substring(
    raw,
    start=split + 1,
    end=raw.length(),
  )
  let status = @string.parse_int(status_raw) catch {
    _ => raise @bit.GitError::ProtocolError("Invalid JS transport status")
  }
  (@bit.HttpResponse::new(status), js_transport_base64_decode(body_b64))
}

///|
extern "js" fn lib_js_transport_get(
  transport_id : Int,
  url : String,
  header_names : Array[String],
  header_values : Array[String],
) -> @js_async.Promise[String] =
  #| async (transportId, url, headerNames, headerValues) => {
  #|   const state = globalThis.__bitGitJsTransportState ??= { nextTransportId: 1, transports: new Map() };
  #|   const transport = state.transports.get(transportId);
  #|   if (!transport || typeof transport.get !== 'function') {
  #|     throw new Error(`bit-git js transport ${transportId} not found`);
  #|   }
  #|   const headers = {};
  #|   for (let i = 0; i < Math.min(headerNames?.length ?? 0, headerValues?.length ?? 0); i++) {
  #|     headers[String(headerNames[i])] = String(headerValues[i]);
  #|   }
  #|   const response = await transport.get(url, headers);
  #|   const status = Math.trunc(response?.status ?? response?.code ?? 200);
  #|   const rawBody = response?.body ?? new Uint8Array();
  #|   const bytes = (() => {
  #|     if (rawBody == null) return new Uint8Array();
  #|     if (rawBody instanceof Uint8Array) return rawBody;
  #|     if (typeof ArrayBuffer !== 'undefined' && rawBody instanceof ArrayBuffer) {
  #|       return new Uint8Array(rawBody);
  #|     }
  #|     if (typeof ArrayBuffer !== 'undefined' && ArrayBuffer.isView(rawBody)) {
  #|       return new Uint8Array(rawBody.buffer, rawBody.byteOffset, rawBody.byteLength);
  #|     }
  #|     if (typeof rawBody === 'string') {
  #|       return new TextEncoder().encode(rawBody);
  #|     }
  #|     return Uint8Array.from(rawBody);
  #|   })();
  #|   const bodyB64 = typeof Buffer !== 'undefined'
  #|     ? Buffer.from(bytes).toString('base64')
  #|     : btoa(Array.from(bytes, b => String.fromCharCode(b)).join(''));
  #|   return `${status}\n${bodyB64}`;
  #| }

///|
extern "js" fn lib_js_transport_post(
  transport_id : Int,
  url : String,
  body : Array[Byte],
  header_names : Array[String],
  header_values : Array[String],
) -> @js_async.Promise[String] =
  #| async (transportId, url, body, headerNames, headerValues) => {
  #|   const state = globalThis.__bitGitJsTransportState ??= { nextTransportId: 1, transports: new Map() };
  #|   const transport = state.transports.get(transportId);
  #|   if (!transport || typeof transport.post !== 'function') {
  #|     throw new Error(`bit-git js transport ${transportId} not found`);
  #|   }
  #|   const headers = {};
  #|   for (let i = 0; i < Math.min(headerNames?.length ?? 0, headerValues?.length ?? 0); i++) {
  #|     headers[String(headerNames[i])] = String(headerValues[i]);
  #|   }
  #|   const response = await transport.post(url, Uint8Array.from(body ?? []), headers);
  #|   const status = Math.trunc(response?.status ?? response?.code ?? 200);
  #|   const rawBody = response?.body ?? new Uint8Array();
  #|   const bytes = (() => {
  #|     if (rawBody == null) return new Uint8Array();
  #|     if (rawBody instanceof Uint8Array) return rawBody;
  #|     if (typeof ArrayBuffer !== 'undefined' && rawBody instanceof ArrayBuffer) {
  #|       return new Uint8Array(rawBody);
  #|     }
  #|     if (typeof ArrayBuffer !== 'undefined' && ArrayBuffer.isView(rawBody)) {
  #|       return new Uint8Array(rawBody.buffer, rawBody.byteOffset, rawBody.byteLength);
  #|     }
  #|     if (typeof rawBody === 'string') {
  #|       return new TextEncoder().encode(rawBody);
  #|     }
  #|     return Uint8Array.from(rawBody);
  #|   })();
  #|   const bodyB64 = typeof Buffer !== 'undefined'
  #|     ? Buffer.from(bytes).toString('base64')
  #|     : btoa(Array.from(bytes, b => String.fromCharCode(b)).join(''));
  #|   return `${status}\n${bodyB64}`;
  #| }

///|
async fn js_transport_get(
  transport_id : Int,
  url : String,
  headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let (header_names, header_values) = js_transport_headers_to_arrays(headers)
  let raw = lib_js_transport_get(transport_id, url, header_names, header_values).wait() catch {
    error => raise @bit.GitError::IoError("JS transport GET failed: \{error}")
  }
  js_transport_parse_response(raw)
}

///|
async fn js_transport_post(
  transport_id : Int,
  url : String,
  body : Bytes,
  headers : Map[String, String],
) -> (@bit.HttpResponse, Bytes) raise @bit.GitError {
  let (header_names, header_values) = js_transport_headers_to_arrays(headers)
  let raw = lib_js_transport_post(
    transport_id,
    url,
    js_transport_bytes_to_array(body),
    header_names,
    header_values,
  ).wait() catch {
    error => raise @bit.GitError::IoError("JS transport POST failed: \{error}")
  }
  js_transport_parse_response(raw)
}
