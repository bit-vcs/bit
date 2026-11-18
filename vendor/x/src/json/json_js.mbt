// JS implementation: drive the host `JSON` through FFI and convert to/from the
// builtin `Json` value type, presenting the same surface as the native engine.
//
// `JSON.parse` runs natively and the resulting tree is walked through FFI to
// build the corresponding `Json`. The dominant cost on this path is building
// the `Json` ADT in MoonBit (which the pure-MoonBit parser also pays), so parse
// lands roughly on par with upstream; `valid` and `stringify`, which avoid
// rebuilding the value, are the clear wins (see `json_bench_wbtest.mbt`).

///|
#external
priv type JsValue

///|
priv struct JsParseResult {
  ok : Bool
  is_eof : Bool
  line : Int32
  column : Int32
  ch_code : Int32
  value : JsValue
}

///|
// Parses `input` with the host `JSON.parse`. On failure the error message is
// scraped for a position so the same `ParseError` shape can be reported.
extern "js" fn js_parse(input : String) -> JsParseResult =
  #| (input) => {
  #|   try {
  #|     return { ok: true, is_eof: false, line: 0, column: 0, ch_code: -1, value: JSON.parse(input) };
  #|   } catch (err) {
  #|     const msg = String((err && err.message) || err);
  #|     // Explicit end-of-input is always EOF.
  #|     if (/end of (JSON|data|input)/i.test(msg)) {
  #|       return { ok: false, is_eof: true, line: 0, column: 0, ch_code: -1, value: null };
  #|     }
  #|     const pm = msg.match(/position (\d+)/i);
  #|     if (pm) {
  #|       const pos = pm[1] | 0;
  #|       // A failure reported at or past the end of input is an EOF, e.g. a
  #|       // dangling minus ("-"), an unterminated string, or "[1" — V8 phrases
  #|       // these with a position rather than "end of input".
  #|       if (pos >= input.length) {
  #|         return { ok: false, is_eof: true, line: 0, column: 0, ch_code: -1, value: null };
  #|       }
  #|       const lc = msg.match(/line (\d+) column (\d+)/i);
  #|       const line = lc ? (lc[1] | 0) : 1;
  #|       const column = lc ? ((lc[2] | 0) - 1) : pos;
  #|       return { ok: false, is_eof: false, line, column, ch_code: input.codePointAt(pos), value: null };
  #|     }
  #|     // "Unexpected token X" without a position: the failure is at the start.
  #|     const ch_code = input.length > 0 ? input.codePointAt(0) : -1;
  #|     return { ok: false, is_eof: false, line: 1, column: 0, ch_code, value: null };
  #|   }
  #| }

///|
extern "js" fn js_valid(input : String) -> Bool =
  #| (input) => {
  #|   try { JSON.parse(input); return true; }
  #|   catch { return false; }
  #| }

///|
extern "js" fn js_typeof(v : JsValue) -> Int32 =
  #| (v) => {
  #|   if (v === null || v === undefined) return 0;
  #|   const t = typeof v;
  #|   if (t === 'boolean') return 1;
  #|   if (t === 'number') return 2;
  #|   if (t === 'string') return 3;
  #|   if (Array.isArray(v)) return 4;
  #|   if (t === 'object') return 5;
  #|   return 0;
  #| }

///|
extern "js" fn js_to_bool(v : JsValue) -> Bool =
  #| (v) => v

///|
extern "js" fn js_to_number(v : JsValue) -> Double =
  #| (v) => v

///|
extern "js" fn js_to_string(v : JsValue) -> String =
  #| (v) => v

///|
extern "js" fn js_array_len(v : JsValue) -> Int32 =
  #| (v) => v.length | 0

///|
extern "js" fn js_array_get(v : JsValue, i : Int32) -> JsValue =
  #| (v, i) => v[i]

///|
extern "js" fn js_object_keys(v : JsValue) -> FixedArray[String] =
  #| (v) => Object.keys(v)

///|
extern "js" fn js_object_get(v : JsValue, k : String) -> JsValue =
  #| (v, k) => v[k]

///|
fn convert(
  v : JsValue,
  depth : Int32,
  max_depth : Int32,
) -> Json raise ParseError {
  match js_typeof(v) {
    1 => @upstream.ToJson::to_json(js_to_bool(v))
    2 => @upstream.ToJson::to_json(js_to_number(v))
    3 => @upstream.ToJson::to_json(js_to_string(v))
    4 => {
      guard depth < max_depth else { raise DepthLimitExceeded }
      let len = js_array_len(v)
      let arr : Array[Json] = []
      for i in 0..<len {
        arr.push(convert(js_array_get(v, i), depth + 1, max_depth))
      }
      @upstream.ToJson::to_json(arr)
    }
    5 => {
      guard depth < max_depth else { raise DepthLimitExceeded }
      let obj : Map[String, Json] = Map([])
      for k in js_object_keys(v) {
        obj[k] = convert(js_object_get(v, k), depth + 1, max_depth)
      }
      @upstream.ToJson::to_json(obj)
    }
    _ => Json::null()
  }
}

///|
/// Parses a JSON document into a `Json` value. `max_nesting_depth` defaults to
/// 1024, matching `moonbitlang/core/json`.
pub fn parse(
  input : StringView,
  max_nesting_depth~ : Int32 = 1024,
) -> Json raise ParseError {
  let result = js_parse(input.to_owned())
  guard result.ok else {
    if result.is_eof {
      raise InvalidEof
    }
    let pos = { line: result.line, column: result.column, }
    let c = if result.ch_code >= 0 {
      Char::from_int(result.ch_code)
    } else {
      ' '
    }
    raise InvalidChar(pos, c)
  }
  convert(result.value, 0, max_nesting_depth)
}

///|
/// Returns whether `input` is a well-formed JSON document.
pub fn valid(input : StringView) -> Bool {
  js_valid(input.to_owned())
}

///|
extern "js" fn js_null() -> JsValue =
  #| () => null

///|
extern "js" fn js_bool(b : Bool) -> JsValue =
  #| (b) => b

///|
extern "js" fn js_number(n : Double) -> JsValue =
  #| (n) => n

///|
extern "js" fn js_str(s : String) -> JsValue =
  #| (s) => s

///|
extern "js" fn js_new_array() -> JsValue =
  #| () => []

///|
extern "js" fn js_array_push(a : JsValue, v : JsValue) -> Unit =
  #| (a, v) => { a.push(v); }

///|
extern "js" fn js_new_object() -> JsValue =
  #| () => ({})

///|
extern "js" fn js_object_set(o : JsValue, k : String, v : JsValue) -> Unit =
  #| (o, k, v) => { o[k] = v; }

///|
extern "js" fn js_stringify(v : JsValue, indent : Int32) -> String =
  #| (v, indent) => JSON.stringify(v, null, indent > 0 ? indent : undefined)

///|
fn to_js(json : Json) -> JsValue {
  match json {
    Null => js_null()
    True => js_bool(true)
    False => js_bool(false)
    Number(n, ..) => js_number(n)
    String(s) => js_str(s)
    Array(arr) => {
      let a = js_new_array()
      for item in arr {
        js_array_push(a, to_js(item))
      }
      a
    }
    Object(obj) => {
      let o = js_new_object()
      for k, v in obj {
        js_object_set(o, k, to_js(v))
      }
      o
    }
  }
}

///|
/// Serializes a `Json` value. `escape_slash` (default false) escapes `/` as
/// `\/`; `indent` (default 0) pretty-prints with that many spaces per level.
pub fn stringify(
  json : Json,
  escape_slash~ : Bool = false,
  indent~ : Int32 = 0,
) -> String {
  let serialized = js_stringify(to_js(json), indent)
  if escape_slash {
    serialized.replace_all(old="/", new="\\/")
  } else {
    serialized
  }
}
