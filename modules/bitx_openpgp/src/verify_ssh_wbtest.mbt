///| Whitebox test for native SSH (SSHSIG) verification, exercised against a
///| real `ssh-keygen -Y sign -n git` signature (fixture from OpenSSH).
test "verify real ssh-keygen ed25519 git signature" {
  let msg = "hello git signing"
  let payload : Bytes = Bytes::makei(msg.length(), fn(i) {
    msg.get_char(i).unwrap().to_int().to_byte()
  })
  let sig_armor =
    #|-----BEGIN SSH SIGNATURE-----
    #|U1NIU0lHAAAAAQAAADMAAAALc3NoLWVkMjU1MTkAAAAg87IrUjpWCUS3yv0YDR71KNHGm9
    #|9iwaqoezx5rJemVxUAAAADZ2l0AAAAAAAAAAZzaGE1MTIAAABTAAAAC3NzaC1lZDI1NTE5
    #|AAAAQGjEo2XckzSHCF3KQjzquSFX31V7/93S5QcbtsKB8Kq+fiFubv+cUCdNRsrvJJZ1eW
    #|USS98VvY3CEN8iz/c7vAE=
    #|-----END SSH SIGNATURE-----
  let allowed_signers = "mizchi@misc-test ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPOyK1I6VglEt8r9GA0e9SjRxpvfYsGqqHs8eayXplcV"
  let good = verify_ssh_detached(payload, sig_armor, allowed_signers)
  inspect(good.verified, content="true")
  // A tampered payload must not verify.
  let bad_payload : Bytes = Bytes::makei(3, fn(_i) { b'\x00' })
  let tampered = verify_ssh_detached(bad_payload, sig_armor, allowed_signers)
  inspect(tampered.verified, content="false")
  // An empty allowed-signers file -> no principal validates it.
  let unknown = verify_ssh_detached(payload, sig_armor, "")
  inspect(unknown.verified, content="false")
}
