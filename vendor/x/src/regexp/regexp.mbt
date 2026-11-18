// Cross-platform regular expressions.
//
// Mirrors the public interface of `moonbitlang/regexp`. On native, wasm and
// wasm-gc the pure-MoonBit engine is delegated to directly. On the JS target
// the host `RegExp` is driven through FFI, returning the same `Regexp` /
// `MatchResult` surface so the same code compiles and behaves identically on
// every target.

///|
/// Regular expression parsing error types.
///
/// Same variants (and meanings) as `moonbitlang/regexp.Err`. The JS backend
/// cannot tell these apart with the same precision as the native parser, so it
/// reports `InternalError` for any pattern the host `RegExp` rejects.
pub enum Err {
  InternalError // Internal error
  InvalidCharClass // Invalid character class
  InvalidEscape // Invalid escape sequence
  InvalidNamedCapture // Invalid named capture group
  InvalidRepeatOp // Invalid repeat operator
  InvalidRepeatSize // Invalid repeat count
  MissingBracket // Missing right bracket ]
  MissingParenthesis // Missing right parenthesis )
  MissingRepeatArgument // Missing repeat argument
  TrailingBackslash // Trailing backslash
  UnexpectedParenthesis // Unexpected parenthesis
}

///|
pub impl Show for Err with fn output(self, logger) {
  logger.write_string(
    match self {
      InternalError => "InternalError"
      InvalidCharClass => "InvalidCharClass"
      InvalidEscape => "InvalidEscape"
      InvalidNamedCapture => "InvalidNamedCapture"
      InvalidRepeatOp => "InvalidRepeatOp"
      InvalidRepeatSize => "InvalidRepeatSize"
      MissingBracket => "MissingBracket"
      MissingParenthesis => "MissingParenthesis"
      MissingRepeatArgument => "MissingRepeatArgument"
      TrailingBackslash => "TrailingBackslash"
      UnexpectedParenthesis => "UnexpectedParenthesis"
    },
  )
}

///|
/// Parsing error raised by `compile`.
pub suberror RegexpError {
  RegexpError(err~ : Err, source_fragment~ : StringView)
}

///|
pub impl Show for RegexpError with fn output(self, logger) {
  let RegexpError(err~, source_fragment~) = self
  logger.write_string("RegexpError(err=")
  Show::output(err, logger)
  logger.write_string(", source_fragment=")
  Show::output(source_fragment, logger)
  logger.write_string(")")
}

///|
pub extend Err with Show::{to_string, output}

///|
pub extend RegexpError with Show::{to_string, output}
