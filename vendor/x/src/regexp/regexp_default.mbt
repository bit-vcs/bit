// Native / wasm / wasm-gc implementation: delegate to the pure-MoonBit
// `moonbitlang/regexp` engine, which compiles to every non-JS target.

///|
fn map_err(err : @upstream.Err) -> Err {
  match err {
    InternalError => InternalError
    InvalidCharClass => InvalidCharClass
    InvalidEscape => InvalidEscape
    InvalidNamedCapture => InvalidNamedCapture
    InvalidRepeatOp => InvalidRepeatOp
    InvalidRepeatSize => InvalidRepeatSize
    MissingBracket => MissingBracket
    MissingParenthesis => MissingParenthesis
    MissingRepeatArgument => MissingRepeatArgument
    TrailingBackslash => TrailingBackslash
    UnexpectedParenthesis => UnexpectedParenthesis
  }
}

///|
/// A compiled regular expression.
pub struct Regexp {
  priv inner : @upstream.Regexp
}

///|
/// Compiles a regular expression. `flags` accepts the same letters as
/// `moonbitlang/regexp`: `i` (ignore case), `m` (multiline), `s` (dot matches
/// newline).
pub fn compile(
  pattern : StringView,
  flags? : StringView,
) -> Regexp raise RegexpError {
  let inner = @upstream.compile(pattern, flags?) catch {
    @upstream.RegexpError(err~, source_fragment~) =>
      raise RegexpError(err=map_err(err), source_fragment~)
  }
  { inner, }
}

///|
/// Executes the regular expression against `input`, returning a `MatchResult`.
pub fn Regexp::execute(self : Regexp, input : StringView) -> MatchResult {
  { inner: self.inner.execute(input), }
}

///|
/// Like `execute`, but returns `None` when there is no match.
pub fn Regexp::match_(self : Regexp, input : StringView) -> MatchResult? {
  self.inner.match_(input).map(inner => { inner, })
}

///|
/// Returns the index of the capture group with the given name, if any.
pub fn Regexp::group_by_name(self : Regexp, name : String) -> Int32? {
  self.inner.group_by_name(name)
}

///|
/// Returns the number of capture groups, including the whole match at index 0.
pub fn Regexp::group_count(self : Regexp) -> Int32 {
  self.inner.group_count()
}

///|
/// Returns the names of all named capture groups.
pub fn Regexp::group_names(self : Regexp) -> Array[String] {
  self.inner.group_names()
}

///|
/// The result of running a regular expression against an input.
pub struct MatchResult {
  priv inner : @upstream.MatchResult
}

///|
/// Whether the match succeeded.
pub fn MatchResult::matched(self : MatchResult) -> Bool {
  self.inner.matched()
}

///|
/// Returns the text of capture group `index` (0 is the whole match), or `None`
/// when the index is out of range or the group did not participate.
pub fn MatchResult::get(self : MatchResult, index : Int32) -> StringView? {
  self.inner.get(index)
}

///|
/// Returns a map of named capture group name to matched text.
pub fn MatchResult::groups(self : MatchResult) -> Map[String, StringView] {
  self.inner.groups()
}

///|
/// Returns the text of every capture group (`None` for groups that did not
/// participate).
pub fn MatchResult::results(self : MatchResult) -> Array[StringView?] {
  self.inner.results()
}

///|
/// The text before the match (the whole input when there is no match).
pub fn MatchResult::before(self : MatchResult) -> StringView {
  self.inner.before()
}

///|
/// The text after the match (empty when there is no match).
pub fn MatchResult::after(self : MatchResult) -> StringView {
  self.inner.after()
}
