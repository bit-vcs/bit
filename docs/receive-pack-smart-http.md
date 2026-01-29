## Smart HTTP receive-pack integration

This project exposes small helpers so you can build a smart HTTP server outside
of this repo while reusing the receive-pack logic.

### Public API you call

- `@mizchi/git/lib::build_receive_pack_advertisement`
- `@mizchi/git/lib::receive_pack`
- `@mizchi/git/lib::receive_pack_info_refs_response`
- `@mizchi/git/lib::receive_pack_response`

`receive_pack_*_response` includes:
- Bearer token check (`Authorization: Bearer <token>`)
- Smart HTTP content types and headers
- Pack handling + ref updates
- Non-fast-forward protection for `refs/heads/*`

### Minimal server flow (pseudo)

```
// GET /info/refs?service=git-receive-pack
let res = receive_pack_info_refs_response(
  rfs,            // RepoFileSystem
  repo_root,      // e.g. "/repos/foo"
  auth_header,    // String? from HTTP header
  token,          // shared secret
  agent="git/myserver"
)
respond(res.status, res.headers, res.body)

// POST /git-receive-pack
let res = receive_pack_response(
  fs,             // FileSystem
  rfs,            // RepoFileSystem
  repo_root,
  auth_header,
  token,
  request_body   // raw bytes
)
respond(res.status, res.headers, res.body)
```

### Notes

- `receive_pack_response` enforces **non-fast-forward rejection** for
  `refs/heads/*`. Deletes are allowed (new id = all-zero).
- The repo must already exist (`repo_root/.git` initialized).
- If you want to customize authorization or policy, call
  `build_receive_pack_advertisement` + `receive_pack` directly.

