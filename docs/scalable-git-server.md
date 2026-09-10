# Scalable Git Server — Design Study

> **Status**: phases 0–2 implemented, phases 3–7 not started. This document
> evaluates what it would take to give `bit` a horizontally scalable Git
> server, using [tobi/walgit](https://github.com/tobi/walgit) and
> [danthegoodman1/waltier](https://github.com/danthegoodman1/waltier) as
> reference architectures, and tracks how far that has been built. Nothing
> here is in a release yet.
>
> Shipped so far: `bit serve --http` (a real listener, local disk),
> `mizchi/bit_objstore` (object storage with compare-and-swap) and
> `mizchi/bitx_wal` (the WAL engine). What remains is the Git-specific layer
> that puts a repository on top of them — see §11.

## 1. Motivation

`bit` already contains a complete server-side Git implementation — `upload-pack`
v0/v2, `receive-pack`, LFS, push policy — but every serving path assumes a
single machine with a local POSIX filesystem:

| Path | Entry point | Scaling ceiling |
|------|-------------|-----------------|
| SSH | `bit shell` (`modules/bit/cmd/bit/shell.mbt`) | one host, local disk, local ref locks |
| Relay tunnel | `bit relay serve` (`modules/bit/cmd/bit/serve.mbt`) | the local process *is* the server; the relay only forwards HTTP |
| Embedded HTTP helpers | `modules/bit_lib/src/smart_http.mbt` | caller supplies its own server and its own filesystem |
| HTTP listener | `bit serve --http` (`modules/bit/cmd/bit/serve_http.mbt`) | **added by this work** — many repositories, still one host and one disk |

There was no path where two processes could serve the same repository, and none
where repository size could exceed one machine's disk. The question this
document answers is: what is the smallest set of changes that removes both
limits? `bit serve --http` closes the "there is no server at all" gap; the
storage work below is what removes the two ceilings, and it is not yet
connected to the serving path.

## 2. Reference architectures

### 2.1 walgit — Git server with a bucket as source of truth

Rust, single binary, no database, no leader, no local state that matters. Per
its README:

- A bucket (S3 / GCS / S3-compatible) holds each repository as an immutable log
  under `repos/<owner>/<repo>/`.
- `manifest.pb` is a tiny file rewritten by compare-and-swap. It holds the head
  sequence, the live pack set, a checkpoint pointer and settings. **The manifest
  rewrite is the only commit point** — "the CAS *is* the consensus — no
  election, no quorum, no primary."
- `log/<seq>.pb` holds immutable entries: `PUSH`, `COMPACT`, `CHECKPOINT`,
  `SETTINGS`.
- `wal/<checksum>.pack|.idx|.rev|.bitmap|.commit-graph` holds content-addressed,
  immutable packs.
- `checkpoints/<seq>/` folds refs plus pack inventory so a cold start only needs
  snapshot + tail replay.
- Push flow: index the incoming pack in scratch → connectivity and policy checks
  → upload pack + idx + log entry → CAS the manifest (retry on 412) →
  acknowledge the client only after the bucket confirms. Concurrent pushes
  group-commit into a single CAS.
- Read flow: conditional GET of the manifest; 304 serves the cached copy, 200
  applies new entries. Sync level decides how much is materialized locally —
  `refs` (skip packs), `serve` (small packs local, oversized bases via HTTP
  range), `full` (everything local), `objects` (remote reader over range
  requests, for repos larger than the machine).
- Bundle-URI on calendar slots — weekly full anchoring daily chains with hourly
  additions — as a pure function of the WAL. Clones fetch the newest full plus
  chain from the bucket and ask the server only for the remainder.
- Crates: `walgit-proto`, `-store`, `-git`, `-wal`, `-bundle`, `-server`,
  `-config`, `-cli`.

### 2.2 waltier — embeddable tiered WAL

Rust library: "memory, local disk, and S3, coordinated by nothing but S3
conditional writes." It generalizes exactly the substrate walgit's manifest is
one instance of:

- Three tiers: memory (application state, rebuilt by replaying entries), local
  disk (optional warm-start cache), S3 (durable source of truth).
- The whole log is **one small S3 object** — the WAL image — containing a
  snapshot pointer plus live entries, CAS'd on every write via ETag.
- Large payloads live as separate immutable objects; entries only reference
  them.
- Snapshots use random 128-bit IDs and create-only PUTs so they can never
  overwrite each other; a background compactor folds and installs them.
- Defaults: 64 MiB encoded WAL image, 1,000,000 live entries, 256 MiB snapshots.
  Batching amortizes one CAS per commit across many entries (group commit).
- Failure taxonomy is explicit: `NotApplied` / `Unknown` / confirmed. GC is
  offline-only so it is safe under concurrency.

### 2.3 What to borrow

| From | Take | Why |
|------|------|-----|
| walgit | bucket layout, manifest-as-linearization-point, packs as immutable payloads, sync levels, bundle-URI, checkpoint shape | Proven mapping of Git semantics onto object storage |
| walgit | "reads start with a conditional GET of the manifest" | Makes replica freshness a single cheap request |
| waltier | generic WAL-over-CAS engine, group commit, snapshot-by-random-ID, explicit `NotApplied`/`Unknown` outcomes, offline-only GC | The reusable substrate — worth building once and reusing for hub records, not just refs |
| waltier | large payloads as separate immutable objects referenced by entries | Packs are exactly this; the rule falls out for free |

The important insight is that these two projects are the *same* design at two
altitudes. If `bit` builds the waltier-shaped engine first, the walgit-shaped
Git server becomes a consumer of it — and `bit issue` / `bit pr` records get a
linearizable backend for free, next to the eventually-consistent gossip path
that `bitx_kv` already provides.

## 3. What bit already has

Substantially more than a greenfield start:

| Capability | Location |
|------------|----------|
| `upload-pack` v0 | `modules/bit_lib/src/upload_pack.mbt:375` |
| `upload-pack` v2 (`ls-refs`, filters, shallow) | `modules/bit_lib/src/upload_pack.mbt:710` |
| `receive-pack` incl. policy, push options, push certs, proc-receive | `modules/bit_lib/src/receive_pack.mbt:384` |
| Smart-HTTP response builders + bearer auth | `modules/bit_lib/src/smart_http.mbt:11,39` |
| Full smart-HTTP routing incl. LFS batch API | `modules/bit/cmd/bit/serve.mbt:804` (`serve_handle_git_request`) |
| Pack write + index generation (content-addressed name) | `modules/bit_pack/src/pack_index_write.mbt:502` |
| Pack bitmaps, commit-graph, multi-pack-index | `modules/bit_pack/`, `bit/cmd/bit/pack_bitmap_*.mbt` |
| Reftable backend | `modules/bit_reftable/` |
| Storage abstraction traits (sync **and** async) | `modules/bit_types/src/contracts.mbt:4,14,23,34` |
| Native async HTTP **server** primitives | `moonbitlang/async/http.Server` (already a dependency) |
| JS host-bridge build (Workers-capable) | `modules/bit_lib/src/js_api_exports.mbt`, `npm/` |

`receive_pack` already persists an incoming push as an immutable
`pack-<sha>.pack` + `.idx` pair (`receive_pack.mbt:334`) — precisely the unit
walgit uploads to the bucket. The Git half of the problem is mostly done; the
storage and coordination half does not exist.

## 4. Gaps

| ID | Gap | Evidence |
|----|-----|----------|
| ~~**G1**~~ | ~~No object-store abstraction (S3 / R2 / GCS). No SigV4 signing; `bit_hash` has SHA-256 but no HMAC.~~ **Closed** by `mizchi/bit_objstore` and `@hash.hmac_sha256_raw`. | `modules/bit_objstore/src/` |
| ~~**G2**~~ | ~~The native HTTP client **discards response headers**, so ETags are invisible — CAS is impossible today.~~ **Closed**: responses now carry their headers. | `modules/bit_io_native/src/http_client_native.mbt` (`http_response_of`) |
| ~~**G3**~~ | ~~No `DELETE`, and no helper for conditional request headers (`If-Match`, `If-None-Match`).~~ **Closed** by `native_http_delete` and `native_objstore_send`. | same file |
| **G4** | `RepoFileSystem::read_file` is whole-file only, and `ObjectDb` loads **entire packs into memory**. Repo size is therefore capped by RAM; walgit's `serve`/`objects` sync levels are unreachable. | `modules/bit_lib/src/object_db.mbt:780,788`; `modules/bit_types/src/contracts.mbt:24` |
| **G5** | The serving path is built on the **sync** traits. A Workers/R2 deployment needs the async traits end to end. | `upload_pack`/`receive_pack` take `&@bit.FileSystem` |
| ~~**G6**~~ | ~~No HTTP listener. `http_serve_native.mbt` is a *client* wrapper; `serve.mbt` only speaks the relay long-poll protocol.~~ **Closed** by `bit serve --http`. | `modules/bit/cmd/bit/serve_http.mbt` |
| **G7** | ~~No multi-repository routing (`/<owner>/<repo>.git/...`)~~ — closed by `bit serve --http`. Per-repository policy and per-user auth are still missing; the listener has one shared bearer token. | `modules/bit/cmd/bit/serve_http.mbt` |

G2 and G3 were small and mechanical, and are done. **G4 and G5 remain, and
they are the structural ones**: until `ObjectDb` can range-read a pack, and
until the serving path can run on the async traits, repository size is capped
by RAM and the Workers deployment is out of reach.

## 5. Proposed architecture

Following the layering in [`package-layout.md`](package-layout.md)
(`core → mid → high → ext → cmd`, dependencies flow downward only):

```
cmd:   bit serve --http                     ← listener, routing, auth
ext:   bitx_gitwal                          ← repo handle, sync levels, publish
ext:   bitx_wal                             ← generic WAL/manifest/CAS/compaction
high:  bit_lib (upload_pack, receive_pack)  ← unchanged
core:  bit_objstore                         ← ObjectStore trait + SigV4 + key codec
core:  bit_pack, bit_refs, bit_hash, ...    ← unchanged
```

### 5.1 `bit_objstore` (core, new)

Pure and IO-free except through an injected transport, so it stays
target-agnostic per [`pure-impl-plan.md`](pure-impl-plan.md):

```moonbit
pub(all) enum PutCondition {
  Unconditional
  IfNotExists          // S3/R2: If-None-Match: *   GCS: ifGenerationMatch=0
  IfMatch(String)      // S3/R2: If-Match: <etag>   GCS: ifGenerationMatch=<gen>
}

pub(all) enum PutOutcome {
  Applied(String)      // new etag/generation
  NotApplied           // precondition failed (412) — safe to re-read and retry
  Unknown              // timeout / 5xx — state indeterminate, must reconcile
}

pub(open) trait ObjectStore {
  async fn get(Self, String, range? : (Int64, Int64)?) -> (Bytes, String) raise
  async fn get_if_none_match(Self, String, String) -> GetOutcome raise
  async fn put(Self, String, Bytes, PutCondition) -> PutOutcome raise
  async fn list(Self, String, after? : String) -> Array[ObjEntry] raise
  async fn delete(Self, String) -> Unit raise
}
```

The `Unknown` variant is taken directly from waltier and is not optional: a PUT
that times out may or may not have landed, and a WAL that treats it as failure
will corrupt itself.

Backends: `S3Store` (SigV4), `R2Store` (S3-compatible, or native bindings when
running on Workers), `GcsStore` (generation preconditions), `MemStore` (tests),
`FsStore` (local dir — makes the whole stack testable without a network).

### 5.2 `bitx_wal` (ext, new)

The waltier-shaped engine, generic over the entry payload:

- `manifest` object at a fixed key, CAS'd on every commit, carrying
  `{ head_seq, snapshot_ptr, live_payloads[], settings }`.
- `log/<seq>` immutable entries; large payloads written to content-addressed
  keys first and only referenced from the entry.
- `append(entries) -> PutOutcome` with group commit: a bounded queue batches
  concurrent appends into one CAS.
- `sync()` — conditional GET of the manifest; `304` ⇒ nothing to do.
- Background compactor: fold live entries into a snapshot under a random
  128-bit ID with a create-only PUT, then install the pointer by CAS.
- GC offline-only, exactly as waltier specifies.

This is the piece worth building carefully, because it is reusable: hub records
(`bitx_hub`) currently sync eventually via gossip (`bitx_kv`); a linearizable
option for the same records is a natural second consumer. The two are
complementary — `bitx_kv` deliberately chooses eventual consistency (see its
README's "Why Not Raft?"), while refs need linearizability.

### 5.3 `bitx_gitwal` (ext, new)

The Git-specific layer over `bitx_wal`:

- `RepoHandle` with a sync level: `Refs` | `Serve` | `Full` | `Objects`.
- Entry kinds: `Push { packs[], ref_updates[] }`, `Compact`, `Checkpoint`,
  `Settings`.
- Publish path: hand the pack produced by `receive_pack` to the WAL as a payload
  and the ref updates as the entry.
- Read path: materialize a `git_dir` view whose `objects/pack` is backed by the
  live pack set from the manifest, then call the existing `upload_pack` /
  `upload_pack_v2` unchanged.

### 5.4 `bit serve --http` (cmd) — built

A `moonbitlang/async/http.Server` listener that routes
`/<owner>/<repo>.git/{info/refs,git-upload-pack,git-receive-pack}` straight to
`bit_lib`'s `upload_pack`, `upload_pack_v2` and `receive_pack`.

It deliberately does **not** reuse `serve_handle_git_request` (`serve.mbt:804`).
That handler rewrites incoming refs into `refs/relay/incoming/*`, which is
right for a tunnel that exposes someone's working repository and wrong for a
server, where a push must land on the ref the client named. The reusable part
turned out to be the `bit_lib` entry points, not the relay's wrapper around
them.

Two things had to be added underneath:

- `upload_pack`, `upload_pack_v2` and `build_upload_pack_advertisement` derived
  their git directory as `<root>/.git` with no way to override it, so a bare
  repository — the normal server layout — advertised no refs at all rather than
  failing. They now take an optional `git_dir_override`, the same escape hatch
  `receive_pack` already had. Defaults are unchanged, so no existing caller
  moves.
- The listener resolves each request's git directory itself, accepting both a
  bare repository and a working copy, and answering 404 when it is neither
  rather than serving an empty one.

Repository paths are used verbatim, never percent-decoded. That keeps
`%2e%2e` from becoming `..`; the cost is that a repository whose name needs
escaping is unreachable, which is the right way round.

LFS and a bucket backend are not wired in yet.

## 6. Bucket layout

Adapted from walgit. `bit` has no protobuf; using JSON for the small
control-plane objects keeps them debuggable and costs nothing at these sizes
(the manifest is a few KB), while packs stay binary.

```
repos/<owner>/<repo>/
  manifest.json                 # CAS point. head_seq, snapshot ptr, live packs, settings
  log/<seq>.json                # immutable: PUSH | COMPACT | CHECKPOINT | SETTINGS
  wal/<packid>.pack             # immutable, content-addressed (pack trailer SHA)
  wal/<packid>.idx
  wal/<packid>.rev              # optional
  wal/<packid>.bitmap           # optional
  checkpoints/<seq>/refs.json   # folded refs
  checkpoints/<seq>/packs.json  # pack inventory
  bundles/list                  # bundle-URI, clone chain
  bundles/catchup               # bundle-URI, fetch chain
  bundles/<slot>.bundle
  policy.toml                   # per-repo push policy (reuse .git/hub/policy.toml shape)
  lfs/objects/<oid>
```

`policy.toml` deliberately reuses the shape `bit pr` already writes to
`.git/hub/policy.toml`, so a repo's push rules are the same document whether it
is served locally or from a bucket.

## 7. Flows

### 7.1 Push

```
1. POST /<owner>/<repo>.git/git-receive-pack
2. parse_receive_pack_request  (bit_lib, unchanged)
3. index the pack in scratch   (bit_pack::write_packfile_with_index → packid)
4. connectivity + policy checks against the manifest's live pack set
5. PUT wal/<packid>.pack, .idx        (create-only; content-addressed ⇒ idempotent)
6. PUT log/<seq>.json                 (create-only; loses the race harmlessly)
7. CAS manifest.json (If-Match: <etag>)
     Applied    → report-status-v2 ok
     NotApplied → re-read manifest, re-check fast-forward, retry from 4
     Unknown    → re-read manifest; if our seq landed, succeed; else retry
8. respond only after the bucket confirms
```

Steps 5 and 6 are safe to repeat because both keys are content- or
sequence-addressed and written create-only. Only step 7 is a commit point.
Concurrent pushes to *different* refs of the same repo can be batched into one
CAS by the group-commit queue.

### 7.2 Fetch / clone

```
1. GET manifest.json with If-None-Match: <cached etag>
     304 → serve from cache
     200 → apply new log entries since head_seq
2. advertise refs from the folded ref state (no pack IO needed — Refs level)
3. on git-upload-pack, resolve wants against the live pack set:
     Serve   → small packs already local; oversized bases via HTTP range
     Full    → everything local
     Objects → remote reader, every base fetched by range request
4. upload_pack / upload_pack_v2 (bit_lib, unchanged)
```

### 7.3 Sync levels

| Level | Local state | Use |
|-------|-------------|-----|
| `Refs` | manifest + folded refs | `ls-remote`, webhooks, routing tier |
| `Serve` | small packs local, big bases by range | default serving replica |
| `Full` | all packs local | maintenance node, backup |
| `Objects` | nothing; every read is a range request | repos larger than the machine |

`Refs` and `Full` are reachable with today's code plus G1–G3. `Serve` and
`Objects` both require G4.

## 8. Compaction, checkpoints, GC

A maintainer loop (one role among several, explicitly configured rather than
inferred — walgit's point 3) recomputes desired state each pass from config plus
the WAL, and publishes results back into the log as `COMPACT` / `CHECKPOINT`
entries. Because results go through the same log, a maintenance pass is just
another writer and needs no special coordination — but it does need a lease
(`leases/` with CAS + TTL) so two maintainers do not repack the same repo twice.

GC deletes packs that no live manifest references. Per waltier, this must be
offline-only with respect to the log: a pack is deletable only after no manifest
version within the retention window references it.

## 9. Bundle-URI

Bundles cut on calendar slots as a pure function of the WAL — weekly full,
daily chain, hourly additions — so any node can compute the same slot set
without coordination. Two lists per repo (`bundles/list` for clones,
`bundles/catchup` for fetches). `bit` already implements `bundle` on the client
side (`modules/bit/cmd/bit/bundle.mbt`), so this is mostly server-side slot
arithmetic plus advertising `bundle-uri` in the v2 capability list.

This is the single biggest cost lever: a fresh clone becomes a bucket download
plus a small remainder fetch, which is why walgit treats it as core rather than
an optimization.

## 10. Deployment targets

**Native single binary.** `bit serve --http` on `moonbitlang/async/http.Server`,
any number of instances pointed at the same bucket, TLS terminated by a reverse
proxy. This is the primary target and needs only the sync traits.

**Cloudflare Workers + R2.** The JS host-bridge build already exists, `bitx_kv`
was written with Workers in mind, and R2 supports conditional PUT with ETags —
so the CAS primitive is available. The blocker is G5: the serving path is built
on the sync traits and Workers IO is async throughout. Either the async trait
variants get an `upload_pack`/`receive_pack` path, or the Worker pre-fetches the
needed packs into memory before calling the sync path (viable only for the
`Refs` level and small repos).

## 11. Phased plan

Each phase is independently useful and independently shippable.

| Phase | Deliverable | Status |
|-------|-------------|--------|
| **0** | `bit serve --http` over local disk, multi-repo routing | **Done** — `modules/bit/cmd/bit/serve_http.mbt`, verified end to end against git 2.43 |
| **1** | `bit_objstore` + `MemStore`/`FsStore`/`S3Store`; response headers, `DELETE`, conditional headers; HMAC-SHA256 for SigV4 | **Done** — `modules/bit_objstore/`, `modules/bit_hash/src/hmac_sha256.mbt` |
| **2** | `bitx_wal` engine + group commit + snapshots, tested against `MemStore` | **Done** — `modules/bitx_wal/` |
| **3** | `bitx_gitwal`: push publishes to the WAL; read path at `Refs` + `Full`. Two instances serve one bucket | Not started — this is where the scalability claim becomes real |
| **4** | Checkpoints, maintainer loop, leases | Not started (the WAL's own compaction and offline sweep exist) |
| **5** | Range reads: `read_file_range` on the FS traits, range-aware `ObjectDb` | Not started ⇒ **G4 still open** |
| **6** | Bundle-URI slots and lists | Not started |
| **7** | LFS on bucket, per-repo auth (OIDC / static tokens), events cursor | Not started |

### What phases 0–2 actually deliver

A working standalone Git server, and a tested storage substrate underneath it
that nothing yet uses. `bit serve --http` serves and accepts pushes over the
smart protocol from local disk; `bit_objstore` and `bitx_wal` are complete and
tested but are not yet on the serving path. **Phase 3 is what connects them**,
and until it lands the server is single-node.

### Three protocol bugs the end-to-end run found

Unit tests and a clean type-check said the listener worked. Pointing real
`git` at it said otherwise, three times, and each defect was in `bit_lib`
rather than in the new code — they affect SSH and the relay just as much.

1. **`ls-refs` was not implemented.** `upload_pack_v2` answered only `fetch`,
   so v2 ref discovery — the step before any fetch — returned an error. A
   default `git clone` has used v2 since git 2.26, so it failed while a v0
   clone succeeded.
2. **`side-band-64k` was advertised and not implemented.** `receive-pack`
   offered the capability and then wrote its report-status unframed, so every
   push died with `protocol error: bad band #117` — 117 being the `u` of
   `unpack ok`. `upload_pack` had been framing its packfile correctly all
   along.
3. **The v2 fetch response put its sections in an illegal order.** Both
   builders emitted acknowledgements and then a packfile, which the protocol
   forbids without an intervening `ready`, and omits entirely once the client
   has sent `done`. Clone was unaffected — with no `have` lines there are no
   acknowledgements to mis-order — so only fetch failed.

The pattern is worth naming: all three are cases of advertising a capability
the server does not honour. A capability list is a promise, and nothing in
the test suite was checking that the promises were kept.

### Notes from building phases 0–2

- The WAL does not keep one object per sequence number, as walgit's `log/<seq>`
  does. It keeps waltier's shape instead: the live entries sit *inside* the
  compare-and-swapped image. The single-object-per-entry design has to answer
  what an entry that was written but never committed means, and both answers
  are wrong — skipping it lets a later writer commit a range that contains it,
  and waiting for it deadlocks on a writer that died. With entries inside the
  image the state cannot arise.
- `PutOutcome::Unknown` earned its place immediately. `MemStore` can commit a
  write and *then* report `Unknown`, and the test that exercises it
  (`wal: a commit that lands but reports Unknown is not applied twice`) fails
  against any implementation that treats indeterminate as failure.
- MoonBit's `String::compare` orders by length before content, so it answers
  that `"b"` sorts before `"aa"`. SigV4 canonical headers, S3 key listings and
  Git ref order are all byte-ordered, so `bit_objstore` carries its own
  `lex_compare`. The AWS test vector failed until the header sort used it.

## 12. Risks and open questions

- **G4 is the real ceiling, and it is still open.** Until `ObjectDb` can read a
  pack by range, "scalable" means "repos that fit in RAM." Phases 0–4 give
  horizontal scalability of *serving*, not of *repository size*. These should
  not be conflated when describing the result.
- **CAS semantics are not uniform.** S3 exposes `If-Match`/`If-None-Match` on
  PUT; R2 supports the same and additionally accepts weak and wildcard ETags;
  GCS uses `ifGenerationMatch`. The `ObjectStore` trait must model all three
  without leaking the differences upward. Older or partial S3-compatible stores
  (some MinIO/Ceph builds) may not support conditional PUT at all — the backend
  must detect and refuse rather than silently lose the CAS.
- **SigV4 cost.** Needs HMAC-SHA256 (not currently in `bit_hash`) plus canonical
  request construction. Non-trivial but well-specified. On Workers the R2
  binding avoids it entirely.
- **MoonBit async HTTP server maturity.** `moonbitlang/async/http.Server` works
  for this purpose — `bit serve --http` is built on it. It offers no TLS
  termination, so a public deployment needs a reverse proxy in front.
- **`Unknown` outcomes must be reconciled, not retried blindly.** A blind retry
  after a timed-out CAS can double-apply a group commit. Handled: every
  `WalEntry` carries an idempotency key, and `append` looks for its own key
  after an indeterminate write instead of guessing. Entries may opt out by
  leaving the key empty, and then two identical appends really are two
  entries — which is tested, so the trade-off is explicit rather than
  accidental.
- **The shared HTTP client can still truncate a body silently.** Its read loop
  treats any read error as end of body, because some servers close abruptly
  once a response is complete. That is tolerable for a clone, which verifies
  its pack, and not for an object-store read, so `native_objstore_send` and
  `native_http_delete` use a strict drain that raises instead. The lenient
  path under `native_http_get`/`post`/`put` is unchanged and remains a latent
  source of silent truncation for clone and fetch; tightening it needs
  testing against real servers that this change did not have.

- **`bit serve --http` buffers whole request and response bodies in memory,**
  with no size cap. A hostile client can therefore make it allocate as much as
  it is willing to send. That is the same ceiling as G4 rather than a separate
  one — the pack handling underneath already holds whole packs in memory — but
  it does mean the listener defaults to loopback and should carry `--token`
  or sit behind an authenticating proxy before it faces a network.

- **Push latency now includes bucket round trips.** walgit's own framing is that
  round trips to object storage drive the design. A push that must PUT a pack,
  PUT a log entry and CAS a manifest is at least three sequential round trips;
  group commit amortizes the third only.

## 13. Non-goals

- Replacing the relay. The relay tunnel solves a different problem (exposing a
  developer's local repo) and stays.
- Replacing `bitx_kv`. Gossip/eventual consistency remains the right answer for
  hub metadata that must work offline; the WAL is for state that must be
  linearizable.
- A web UI. walgit ships one; that is out of scope here.
- Strong multi-region consistency. A single bucket is the consistency domain,
  as in both references.

## 14. References

- [tobi/walgit](https://github.com/tobi/walgit) — Git server with a bucket as
  source of truth
- [danthegoodman1/waltier](https://github.com/danthegoodman1/waltier) —
  embeddable tiered WAL coordinated by S3 conditional writes
- [Amazon S3 conditional writes](https://aws.amazon.com/about-aws/whats-new/2024/11/amazon-s3-functionality-conditional-writes)
- [Cloudflare R2 S3 API extensions](https://developers.cloudflare.com/r2/api/s3/extensions/)
- [`package-layout.md`](package-layout.md) — module layering rules
- [`pure-impl-plan.md`](pure-impl-plan.md) — target-agnostic core direction
- [`receive-pack-smart-http.md`](receive-pack-smart-http.md) — current embedding API
- [`bit-relay-spec.md`](bit-relay-spec.md) — relay protocol (unchanged by this design)
