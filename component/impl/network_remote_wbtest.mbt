///|
test "component impl: network remote helpers normalize ssh remotes" {
  inspect(
    net_normalize_remote_for_http_transport("git@github.com:mizchi/bit-vcs.git"),
    content="https://github.com/mizchi/bit-vcs.git",
  )

  let remote = net_http_remote("git@github.com:user/repo.git")
  inspect(
    remote.info_refs_url(),
    content="https://github.com/user/repo/info/refs?service=git-receive-pack",
  )
  inspect(
    remote.receive_pack_url(),
    content="https://github.com/user/repo/git-receive-pack",
  )
}
