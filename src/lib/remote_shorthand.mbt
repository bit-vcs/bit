///| Clone target result facade type for backward compatibility.

///|
pub(all) enum GitHubShorthand {
  Repo(String, String?) // github_url, ref?
  Subdir(String, String, String?) // github_url, subdir_path, ref?
  File(String, String) // raw_url, filename
} derive(Eq, Show)

///|
fn from_remote_shorthand(value : @gitremote.GitHubShorthand) -> GitHubShorthand {
  match value {
    @gitremote.GitHubShorthand::Repo(url, ref_spec) => Repo(url, ref_spec)
    @gitremote.GitHubShorthand::Subdir(url, path, ref_spec) =>
      Subdir(url, path, ref_spec)
    @gitremote.GitHubShorthand::File(url, name) => File(url, name)
  }
}

///|
pub fn parse_github_shorthand(url : String) -> GitHubShorthand? {
  match @gitremote.parse_github_shorthand(url) {
    Some(value) => Some(from_remote_shorthand(value))
    None => None
  }
}

///|
pub fn check_shorthand_ambiguity(
  url : String,
  dir_exists : (String) -> Bool,
) -> String? {
  @gitremote.check_shorthand_ambiguity(url, dir_exists)
}
