///| Clone target result facade type for backward compatibility.

///|
pub(all) enum GitHubShorthand {
  Repo(String, String?) // github_url, ref?
  Subdir(String, String, String?) // github_url, subdir_path, ref?
  File(String, String) // raw_url, filename
} derive(Eq, Show)

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
