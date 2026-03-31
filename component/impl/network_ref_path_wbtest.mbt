///|
test "component impl: network ref path helpers map refs and parent dirs" {
  inspect(
    net_parent_dir("/repo/.git/refs/heads/main"),
    content="/repo/.git/refs/heads",
  )
  inspect(net_parent_dir("plain"), content="/")
  inspect(
    net_remote_refname("refs/heads/main"),
    content="refs/remotes/origin/main",
  )
  inspect(net_remote_refname("HEAD"), content="refs/remotes/origin/HEAD")
}
