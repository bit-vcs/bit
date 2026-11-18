// Cross-platform JSON.
//
// Mirrors the `parse` / `valid` / `stringify` surface of
// `moonbitlang/core/json`, reusing the builtin `Json` value type. On native,
// wasm and wasm-gc the pure-MoonBit parser/serializer is delegated to. On the
// JS target the host `JSON.parse` / `JSON.stringify` are driven through FFI and
// the result is converted to/from the builtin `Json`, so the same code behaves
// identically on every target.
//
// `Position` and `ParseError` mirror `moonbitlang/core/json` exactly (same
// fields, variants, `Show` messages and derived `Debug` format) so the upstream
// parse tests pass unchanged.

///|
/// A position in the source text. `line` is 1-based, `column` is 0-based, the
/// same convention as `moonbitlang/core/json.Position`.
#derive(Eq, ToJson, @debug.Debug)
pub(all) struct Position {
  line : Int32
  column : Int32
}

///|
/// Parsing error raised by `parse`.
///
/// Same variants as `moonbitlang/core/json.ParseError`. The JS backend can only
/// report what the host parser exposes: it produces `InvalidEof` when the host
/// runs out of input and `InvalidChar` (with the reported position and
/// offending character) otherwise. It never produces `InvalidNumber` /
/// `InvalidIdentEscape`, which are native-parser specific.
#derive(Eq, ToJson, @debug.Debug)
pub(all) suberror ParseError {
  InvalidChar(Position, Char)
  InvalidEof
  InvalidNumber(Position, String)
  InvalidIdentEscape(Position)
  DuplicateKey(Position, String)
  DepthLimitExceeded
}

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    InvalidChar({ line, column, }, c) => {
      logger.write_string("Invalid character ")
      logger.write_string(c.escape())
      logger.write_string(" at line ")
      logger.write_object(line)
      logger.write_string(", column ")
      logger.write_object(column)
    }
    InvalidEof => logger.write_string("Unexpected end of file")
    DuplicateKey({ line, column, }, key) =>
      logger.write_string(
        "Duplicate key \{key.escape()} at line \{line}, column \{column}",
      )
    InvalidNumber({ line, column, }, s) => {
      logger.write_string("Invalid number ")
      logger.write_string(s)
      logger.write_string(" at line ")
      logger.write_object(line)
      logger.write_string(", column ")
      logger.write_object(column)
    }
    InvalidIdentEscape({ line, column, }) => {
      logger.write_string("Invalid escape sequence in identifier at line ")
      logger.write_object(line)
      logger.write_string(", column ")
      logger.write_object(column)
    }
    DepthLimitExceeded =>
      logger.write_string(
        "Depth limit exceeded, please increase the max_nesting_depth parameter",
      )
  }
}

///|
pub extend Position with Eq::{not_equal, equal}

///|
pub extend Position with ToJson::{to_json}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
pub extend ParseError with ToJson::{to_json}

///|
pub extend ParseError with @debug.Debug::{to_repr}

///|
pub extend ParseError with Show::{to_string, output}
