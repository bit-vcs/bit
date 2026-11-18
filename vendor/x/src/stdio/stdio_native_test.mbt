///|
async test "write @stdio.stdout" {
  @stdio.stdout.write(b"stdio test: stdout\n")
}

///|
async test "write @stdio.stderr" {
  @stdio.stderr.write(b"stdio test: stderr\n")
}

///|
test "fd values" {
  inspect(@stdio.stdin.fd(), content="0")
  inspect(@stdio.stdout.fd(), content="1")
  inspect(@stdio.stderr.fd(), content="2")
}
