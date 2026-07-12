///| Clone target result facade type for backward compatibility.

///|
pub(all) enum GitHubShorthand {
  Repo(String, String?) // github_url, ref?
  Subdir(String, String, String?) // github_url, subdir_path, ref?
  File(String, String) // raw_url, filename
} derive(Eq, Debug)

///|
fn bitcore_shorthand_show_string(value : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  for c in value {
    if c == '"' {
      buf.write_string("\\\"")
    } else if c == '\\' {
      buf.write_string("\\\\")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if c == '\t' {
      buf.write_string("\\t")
    } else {
      buf.write_char(c)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn bitcore_shorthand_show_string_option(value : String?) -> String {
  match value {
    Some(s) => "Some(" + bitcore_shorthand_show_string(s) + ")"
    None => "None"
  }
}

///|
pub impl Show for GitHubShorthand with fn output(self, logger) {
  match self {
    Repo(url, ref_spec) =>
      logger.write_string(
        "Repo(" +
        bitcore_shorthand_show_string(url) +
        ", " +
        bitcore_shorthand_show_string_option(ref_spec) +
        ")",
      )
    Subdir(url, path, ref_spec) =>
      logger.write_string(
        "Subdir(" +
        bitcore_shorthand_show_string(url) +
        ", " +
        bitcore_shorthand_show_string(path) +
        ", " +
        bitcore_shorthand_show_string_option(ref_spec) +
        ")",
      )
    File(url, name) =>
      logger.write_string(
        "File(" +
        bitcore_shorthand_show_string(url) +
        ", " +
        bitcore_shorthand_show_string(name) +
        ")",
      )
  }
}

///|
fn from_remote_shorthand(value : @bitremote.GitHubShorthand) -> GitHubShorthand {
  match value {
    @bitremote.GitHubShorthand::Repo(url, ref_spec) => Repo(url, ref_spec)
    @bitremote.GitHubShorthand::Subdir(url, path, ref_spec) =>
      Subdir(url, path, ref_spec)
    @bitremote.GitHubShorthand::File(url, name) => File(url, name)
  }
}

///|
pub fn parse_github_shorthand(url : String) -> GitHubShorthand? {
  match @bitremote.parse_github_shorthand(url) {
    Some(value) => Some(from_remote_shorthand(value))
    None => None
  }
}

///|
pub fn check_shorthand_ambiguity(
  url : String,
  dir_exists : (String) -> Bool,
) -> String? {
  @bitremote.check_shorthand_ambiguity(url, dir_exists)
}
