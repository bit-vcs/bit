///|
type GrepPatternType = @bitgrep.GrepPatternType

///|
fn resolve_grep_pattern_type(
  rfs : &@bitcore.RepoFileSystem,
  git_dir : String,
  cli_override : GrepPatternType?,
) -> GrepPatternType {
  @bitgrep.resolve_grep_pattern_type(
    rfs,
    git_dir,
    cli_override,
    get_config_override("grep.patterntype"),
  )
}

///|
fn grep_patterns_match_message(
  message : String,
  patterns : Array[String],
  pattern_type : GrepPatternType,
  ignore_case : Bool,
) -> Bool {
  @bitgrep.grep_patterns_match_message(
    message, patterns, pattern_type, ignore_case,
  )
}

///|
fn grep_message_matches_pattern(
  message : String,
  pattern : String,
  pattern_type : GrepPatternType,
  ignore_case : Bool,
) -> Bool {
  @bitgrep.grep_message_matches_pattern(
    message, pattern, pattern_type, ignore_case,
  )
}

///|
fn extract_commit_message_from_raw(data : Bytes) -> String {
  @bitgrep.extract_commit_message_from_raw(data)
}
