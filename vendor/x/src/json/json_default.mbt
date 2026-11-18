// Native / wasm / wasm-gc implementation: delegate to the pure-MoonBit
// `moonbitlang/core/json` package, which compiles to every non-JS target.

///|
fn map_position(p : @upstream.Position) -> Position {
  { line: p.line, column: p.column, }
}

///|
fn map_parse_error(e : @upstream.ParseError) -> ParseError {
  match e {
    InvalidChar(pos, c) => InvalidChar(map_position(pos), c)
    InvalidEof => InvalidEof
    InvalidNumber(pos, s) => InvalidNumber(map_position(pos), s)
    InvalidIdentEscape(pos) => InvalidIdentEscape(map_position(pos))
    DuplicateKey(pos, key) => DuplicateKey(map_position(pos), key)
    DepthLimitExceeded => DepthLimitExceeded
  }
}

///|
/// Parses a JSON document into a `Json` value. `max_nesting_depth` defaults to
/// 1024, matching `moonbitlang/core/json`.
pub fn parse(
  input : StringView,
  max_nesting_depth~ : Int32 = 1024,
) -> Json raise ParseError {
  @upstream.parse(input, max_nesting_depth~) catch {
    e => raise map_parse_error(e)
  }
}

///|
/// Returns whether `input` is a well-formed JSON document.
pub fn valid(input : StringView) -> Bool {
  @upstream.valid(input)
}

///|
/// Serializes a `Json` value. `escape_slash` (default false) escapes `/` as
/// `\/`; `indent` (default 0) pretty-prints with that many spaces per level.
pub fn stringify(
  json : Json,
  escape_slash~ : Bool = false,
  indent~ : Int32 = 0,
) -> String {
  json.stringify(escape_slash~, indent~)
}
