# bit-relay Protocol Specification (Draft)

## 1. Purpose and Scope

This specification defines the relay protocol used by `bit relay sync`.
It covers the following:

- Relay server HTTP / WebSocket API
- How the `bit` client uses the relay (explicit relay URL and smart-http fallback)
- Minimum contract for `hub.record` payloads

The Git smart-http specification itself (`/info/refs`, pack protocol) is out of scope.

## 2. Terminology

- `Room`: A logical channel within the relay. Default is `main`.
- `Envelope`: A single message relayed by the relay.
- `Cursor`: A 0-based integer representing a position in the room's envelope array.
- `HubRecord`: A record held by `bit x/hub` (text-serialized).

## 3. URL and Transport Selection

`bit relay sync` accepts the following URLs:

- `relay+http://host[:port]`
- `relay+https://host[:port]`
- `relay://host[:port]` (treated as `http://`)
- `http://...` / `https://...` (tries smart-http first)

### 3.1 Explicit Relay

For `relay+http(s)://...` or `relay://...`, `bit` directly uses the relay API.

### 3.2 Smart-http Fallback

For `http(s)://...`, `bit` first attempts smart-http push/fetch.
It falls back to relay **only when a ProtocolError with a message containing `HTTP 404` occurs**.

## 4. Envelope Schema

The JSON shape of envelopes stored and returned by the relay is as follows:

```json
{
  "room": "main",
  "id": "msg-1",
  "sender": "alice",
  "topic": "notify",
  "payload": { "kind": "hub.record", "record": "..." },
  "signature": null
}
```

- `room`: string, required
- `id`: string, required
- `sender`: string, required
- `topic`: string, required
- `payload`: any JSON
- `signature`: string | null

## 5. HTTP API

### 5.1 `POST /api/v1/publish`

query parameter:

- `room` (optional, default `main`)
- `sender` (required)
- `topic` (optional, default `notify`)
- `id` (optional, default `${sender}-${Date.now()}`)
- `sig` (optional; stored in envelope.signature)

request body:

- JSON text (the `bit` client sends an object)

response:

- `200 OK`

```json
{ "ok": true, "accepted": true, "cursor": 1 }
```

`accepted=false` indicates duplicate reception due to a duplicate ID (idempotent).

error:

- `400` + `{"ok":false,"error":"missing query: sender"}`
- `400` + `{"ok":false,"error":"unsupported topic: <topic>"}`
- `400` + `{"ok":false,"error":"invalid json payload"}`

### Duplicate Detection

In the implementation, an envelope with the same `id` in the same room is rejected as a duplicate (`accepted=false`).

### 5.2 `GET /api/v1/poll`

query parameter:

- `room` (optional, default `main`)
- `after` (optional, default `0`, `after < 0` is normalized to `0`)
- `limit` (optional, default `100`, `limit <= 0` is normalized to `1`)

response:

- `200 OK`

```json
{
  "ok": true,
  "room": "main",
  "next_cursor": 1,
  "envelopes": [/* Envelope[] */]
}
```

`next_cursor = after + envelopes.length`.

### 5.3 `GET /health`

Used for connectivity checks.

```json
{ "status": "ok", "service": "bit-relay" }
```

## 6. WebSocket API

endpoint:

- `GET /ws?room=<room>`
- `Upgrade: websocket` is required (returns `426` otherwise)

Server-sent messages:

- Immediately after connection: `{"type":"ready"}`
- When `publish` results in `accepted=true`:

```json
{
  "type": "notify",
  "room": "main",
  "cursor": 1,
  "envelope": { /* Envelope */ }
}
```

Client-sent messages:

- Sending `{"type":"ping"}` returns `{"type":"pong"}`

## 7. `bit` Client Contract

### 7.1 Push (`bit relay sync push`)

In relay mode:

1. Read `refs/notes/bit-hub` (fail if absent)
2. Enumerate records under `hub/` (including deletion tombstones)
3. `POST /api/v1/publish` for each record with:
   - `room=main`
   - `sender=bit`
   - `topic=notify`
   - `id=<blob-id(hex) of record.serialize()>`
   - body:
     - `{"kind":"hub.record","record":"<serialized HubRecord>"}`
4. Tally the count of `accepted=true` responses

### 7.2 Fetch (`bit relay sync fetch`)

In relay mode:

1. Read the local cursor from `.git/hub/relay-cursor/<hash(remote_base_url)>` (default `0` if absent)
2. `GET /api/v1/poll?room=main&after=<cursor>&limit=200`
3. Only process envelopes where `payload.kind == "hub.record"`
4. Parse/merge `payload.record` as a `HubRecord`
5. If there are changes, commit to `refs/notes/bit-hub`
6. Save `next_cursor`

## 8. `hub.record` Payload

The `record` in the payload relayed by the relay is a `bit` `HubRecord::serialize()` string.
It follows a header + blank line + body format.

Example:

```text
version 1
key hub/issue/082e0cda/meta
kind hub.issue
clock node-a=1
timestamp 1770655267
node node-a
deleted 0

{"title":"relay-issue-1","body":"relay-body-1"}
```

## 9. Compatibility Notes

- The current relay implementation only accepts `topic=notify`.
- Authentication and signature verification are not implemented (`sig` is stored transparently only).
- The relay preserves and returns unknown envelope/payload fields as-is.

## 10. Clone Signaling (Addition)

Data transfer for `bit clone` is performed peer-to-peer; the relay is only used for peer discovery.

- publish:
  - `topic=notify`
  - `payload.kind=bit.clone.announce.v1`
  - `payload.clone_url=<smart-http endpoint>`
  - `payload.repo=<optional repo label>`
- poll:
  - Extract envelopes with `payload.kind=bit.clone.announce.v1` from `GET /api/v1/poll`
  - For multiple announces from the same `sender`, only the latest one is considered valid

CLI:

- `bit relay sync clone-announce [<remote-url>] --url <clone-url> [--repo <repo>]`
- `bit relay sync clone-peers [<remote-url>] [--include-self]`
- `bit clone relay+http(s)://<relay-host> [--relay-sender <sender>] [--relay-repo <repo>]` uses the same discovery logic as `clone-peers` to select one peer and clone from it
  - Defaults to the first peer
  - Setting `BIT_RELAY_CLONE_SENDER=<sender>` prioritizes that sender
  - `BIT_RELAY_CLONE_REPO=<repo>` or `--relay-repo` prioritizes peers matching the repo name (sender takes priority if both are specified)
- `bit fetch relay+http(s)://<relay-host> [--relay-sender <sender>] [--relay-repo <repo>]` uses the same discovery logic to select one peer and fetch from it
  - `BIT_RELAY_FETCH_SENDER=<sender>` / `BIT_RELAY_FETCH_REPO=<repo>` specify default priority conditions
- `bit pull relay+http(s)://<relay-host> [--relay-sender <sender>] [--relay-repo <repo>]` uses the same discovery logic to select one peer and pull from it
  - `BIT_RELAY_PULL_SENDER=<sender>` / `BIT_RELAY_PULL_REPO=<repo>` specify default priority conditions
- `bit push relay+http(s)://<relay-host> [--relay-sender <sender>] [--relay-repo <repo>]` uses the same discovery logic to select one peer and push to it
  - `BIT_RELAY_PUSH_SENDER=<sender>` / `BIT_RELAY_PUSH_REPO=<repo>` specify default priority conditions

---

This specification is a draft aligned with the current implementation (`bit` and `bit-relay`) and will be updated as topic extensions and authentication are added.

## 11. Benchmarks (k6)

- Scenario: `tools/relay-k6-scenario.js`
- Run with local relay startup:
  - `bash tools/bench-relay-k6.sh`
- Example (15 seconds, publish 120 req/s, poll 12 VU):
  - `K6_BENCH_DURATION=15s K6_PUBLISH_RATE=120 K6_POLL_VUS=12 bash tools/bench-relay-k6.sh`
- For poll-only benchmarking on a signature-required relay (e.g., Cloudflare Worker):
  - `RELAY_BASE_URL=https://bit-relay.mizchi.workers.dev K6_PUBLISH_RATE=0 K6_POLL_VUS=20 bash tools/bench-relay-k6.sh`
- For benchmarking with publish on a signature-required relay (auto-starts local signer):
  - `RELAY_BASE_URL=https://bit-relay.mizchi.workers.dev RELAY_SIGN_PRIVATE_KEY_FILE=~/.config/bit/relay-ed25519.pem K6_PUBLISH_RATE=80 K6_POLL_VUS=8 bash tools/bench-relay-k6.sh`
  - The public key can be explicitly specified with `RELAY_SIGN_PUBLIC_KEY=<base64url>` if needed
