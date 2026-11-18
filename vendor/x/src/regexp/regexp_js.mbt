// JS implementation: drive the host `RegExp` through FFI while presenting the
// same `Regexp` / `MatchResult` surface as the native engine.

///|
priv struct JsCompileResult {
  ok : Bool
  error : String
  id : Int32
  capture : Int32
  group_names : FixedArray[String]
  group_indices : FixedArray[Int32]
}

///|
// Compiles `source` into a host RegExp stored in a global registry. The MoonBit
// flag letters (i/m/s) map straight onto the JS ones; the `d` flag is always
// added so `exec` reports capture offsets via `match.indices`. Capturing group
// count and named-group indices are derived by scanning the source the same way
// the native parser numbers groups.
extern "js" fn js_compile(source : String, flags : String) -> JsCompileResult =
  #| (source, flags) => {
  #|   const state = (globalThis.__xRegexp ??= { nextId: 1, regexps: new Map() });
  #|   let f = 'd';
  #|   if (flags.includes('i')) f += 'i';
  #|   if (flags.includes('m')) f += 'm';
  #|   if (flags.includes('s')) f += 's';
  #|   let re;
  #|   try {
  #|     re = new RegExp(source, f);
  #|   } catch (err) {
  #|     return { ok: false, error: String((err && err.message) || err), id: 0, capture: 0, group_names: [], group_indices: [] };
  #|   }
  #|   const names = [];
  #|   const indices = [];
  #|   let count = 0;
  #|   let inClass = false;
  #|   for (let i = 0; i < source.length; i++) {
  #|     const c = source[i];
  #|     if (c === '\\') { i++; continue; }
  #|     if (inClass) { if (c === ']') inClass = false; continue; }
  #|     if (c === '[') { inClass = true; continue; }
  #|     if (c === '(') {
  #|       if (source[i + 1] === '?') {
  #|         if (source[i + 2] === '<' && source[i + 3] !== '=' && source[i + 3] !== '!') {
  #|           count++;
  #|           let j = i + 3;
  #|           let name = '';
  #|           while (j < source.length && source[j] !== '>') { name += source[j]; j++; }
  #|           names.push(name);
  #|           indices.push(count);
  #|         }
  #|       } else {
  #|         count++;
  #|       }
  #|     }
  #|   }
  #|   const id = state.nextId++;
  #|   state.regexps.set(id, re);
  #|   return { ok: true, error: '', id, capture: count + 1, group_names: names, group_indices: indices };
  #| }

///|
priv struct JsExecResult {
  captures : FixedArray[Int32]
}

///|
// Runs the stored RegExp once against `input`. Returns a flat array of
// start/end offset pairs (`-1, -1` for groups that did not participate); an
// empty array means no match.
extern "js" fn js_execute(id : Int32, input : String) -> JsExecResult =
  #| (id, input) => {
  #|   const re = globalThis.__xRegexp?.regexps?.get(id);
  #|   if (!re) return { captures: [] };
  #|   re.lastIndex = 0;
  #|   const m = re.exec(input);
  #|   if (!m) return { captures: [] };
  #|   const idx = m.indices;
  #|   const out = [];
  #|   for (let i = 0; i < idx.length; i++) {
  #|     const pair = idx[i];
  #|     if (pair) { out.push(pair[0] | 0, pair[1] | 0); }
  #|     else { out.push(-1, -1); }
  #|   }
  #|   return { captures: out };
  #| }

///|
/// A compiled regular expression.
pub struct Regexp {
  priv id : Int32
  priv capture : Int32
  priv names : Map[String, Int32]
}

///|
/// Compiles a regular expression. `flags` accepts the same letters as
/// `moonbitlang/regexp`: `i` (ignore case), `m` (multiline), `s` (dot matches
/// newline).
pub fn compile(
  pattern : StringView,
  flags? : StringView,
) -> Regexp raise RegexpError {
  let flags_str = match flags {
    Some(f) => f.to_owned()
    None => ""
  }
  let result = js_compile(pattern.to_owned(), flags_str)
  guard result.ok else {
    raise RegexpError(err=InternalError, source_fragment=pattern)
  }
  let names : Map[String, Int32] = Map([])
  for i in 0..<result.group_names.length() {
    names[result.group_names[i]] = result.group_indices[i]
  }
  { id: result.id, capture: result.capture, names, }
}

///|
/// Executes the regular expression against `input`, returning a `MatchResult`.
pub fn Regexp::execute(self : Regexp, input : StringView) -> MatchResult {
  let owned = input.to_owned()
  let result = js_execute(self.id, owned)
  { input: owned, captures: result.captures, names: self.names, }
}

///|
/// Like `execute`, but returns `None` when there is no match.
pub fn Regexp::match_(self : Regexp, input : StringView) -> MatchResult? {
  let result = self.execute(input)
  if result.matched() {
    Some(result)
  } else {
    None
  }
}

///|
/// Returns the index of the capture group with the given name, if any.
pub fn Regexp::group_by_name(self : Regexp, name : String) -> Int32? {
  self.names.get(name)
}

///|
/// Returns the number of capture groups, including the whole match at index 0.
pub fn Regexp::group_count(self : Regexp) -> Int32 {
  self.capture
}

///|
/// Returns the names of all named capture groups.
pub fn Regexp::group_names(self : Regexp) -> Array[String] {
  self.names.keys().collect()
}

///|
/// The result of running a regular expression against an input.
pub struct MatchResult {
  priv input : String
  priv captures : FixedArray[Int32]
  priv names : Map[String, Int32]
}

///|
/// Whether the match succeeded.
pub fn MatchResult::matched(self : MatchResult) -> Bool {
  !self.captures.is_empty()
}

///|
/// Returns the text of capture group `index` (0 is the whole match), or `None`
/// when the index is out of range or the group did not participate.
pub fn MatchResult::get(self : MatchResult, index : Int32) -> StringView? {
  if self.captures.is_empty() ||
    index < 0 ||
    index >= self.captures.length() / 2 {
    return None
  }
  let start = self.captures[index * 2]
  let end = self.captures[index * 2 + 1]
  if start < 0 || end < start || end > self.input.length() {
    return None
  }
  Some(self.input.exact_view(start~, end~))
}

///|
/// Returns a map of named capture group name to matched text.
pub fn MatchResult::groups(self : MatchResult) -> Map[String, StringView] {
  self.names
  .iter()
  .filter_map(p => {
    if self.get(p.1) is Some(content) {
      Some((p.0, content))
    } else {
      None
    }
  })
  |> Map::from_iter
}

///|
/// Returns the text of every capture group (`None` for groups that did not
/// participate).
pub fn MatchResult::results(self : MatchResult) -> Array[StringView?] {
  let results = []
  for i in 0..<(self.captures.length() / 2) {
    let start = self.captures[i * 2]
    let end = self.captures[i * 2 + 1]
    if start == -1 && end == -1 {
      results.push(None)
    } else {
      results.push(Some(self.input.exact_view(start~, end~)))
    }
  }
  results
}

///|
/// The text before the match (the whole input when there is no match).
pub fn MatchResult::before(self : MatchResult) -> StringView {
  if self.captures.is_empty() {
    self.input.exact_view(start=0)
  } else {
    self.input.exact_view(end=self.captures[0])
  }
}

///|
/// The text after the match (empty when there is no match).
pub fn MatchResult::after(self : MatchResult) -> StringView {
  if self.captures.is_empty() {
    self.input.exact_view(start=self.input.length())
  } else {
    self.input.exact_view(start=self.captures[1])
  }
}
