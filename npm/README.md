# @mizchi/bit

Experimental Git implementation in MoonBit.

This package exposes:

- `bit` CLI
- a tree-shakable JS library API at `@mizchi/bit/lib`

## Install

```bash
npm install @mizchi/bit
```

## CLI

```bash
npx bit init
npx bit status
npx bit add hello.txt
npx bit commit -m "initial commit"
```

Or use the installed binary:

```bash
bit init
bit status
```

## JS Library

The library API is designed for bundlers.
It does not rely on `registerRuntime()`.
Use named imports so unused operations can be tree-shaken.
Every operation accepts your backend as the first argument.

```ts
import {
  add,
  type BitGitBackend,
  branchList,
  buildCommitPayload,
  commit,
  commitWithSigner,
  createFetchTransport,
  fetch,
  init,
  log,
  merge,
  relayListClonePeers,
  relayResolveRemote,
  push,
  rebaseStart,
  status,
  writeString,
} from "@mizchi/bit/lib";

declare const backend: BitGitBackend;

init(backend, "/repo", "main");
writeString(backend, "/repo/hello.txt", "hello\n");
console.log(status(backend, "/repo").untracked);

add(backend, "/repo", ["hello.txt"]);
const commitId = commit(
  backend,
  "/repo",
  "initial commit",
  "Example <example@example.com>",
  1700000000,
);

console.log(commitId);
console.log(branchList(backend, "/repo"));
console.log(log(backend, "/repo", 10));

const mergeResult = merge(
  backend,
  "/repo",
  "feature",
  "merge feature",
  "Example <example@example.com>",
);
console.log(mergeResult.status);

const rebaseResult = rebaseStart(backend, "/repo", "origin/main");
console.log(rebaseResult.status);

const payload = buildCommitPayload(
  backend,
  "/repo",
  "signed commit",
  "Example <example@example.com>",
  1700000001,
);

const signedCommitId = await commitWithSigner(
  backend,
  "/repo",
  "signed commit",
  "Example <example@example.com>",
  async (payloadToSign) => {
    const bytes = new TextEncoder().encode(payloadToSign);
    const signature = await crypto.subtle.sign("Ed25519", privateKey, bytes);
    return encodeArmoredSignature(signature);
  },
  1700000001,
);

console.log(payload);
console.log(signedCommitId);

const transport = createFetchTransport(fetch);
const fetched = await fetch(
  backend,
  "/repo",
  "https://github.com/example/repo.git",
  transport,
  { refspec: "main" },
);
console.log(fetched);

await push(
  backend,
  "/repo",
  "https://github.com/example/repo.git",
  transport,
  { refname: "refs/heads/main" },
);
```

## Relay Remotes

When your client connects to peers through `bit-relay`, pass the relay URL directly.
`fetch()` and `push()` will resolve the relay remote first, then talk to the selected peer.

```ts
import {
  createFetchTransport,
  fetch,
  push,
  relayListClonePeers,
  relayResolveRemote,
} from "@mizchi/bit/lib";

const transport = createFetchTransport(globalThis.fetch);

const peers = await relayListClonePeers(
  "relay+https://relay.example.com/base?room=team-a&room_token=token-1",
  transport,
  { authToken: "relay-auth-token" },
);

const resolved = await relayResolveRemote(
  "relay+https://relay.example.com/base?room=team-a",
  transport,
  { preferredSender: "node-b" },
);

await fetch(
  backend,
  "/repo",
  "relay+https://relay.example.com/base?room=team-a",
  transport,
  {
    refspec: "main",
    preferredRepo: "repo-b",
    authToken: "relay-auth-token",
  },
);

await push(
  backend,
  "/repo",
  "relay+https://relay.example.com/base/AbCd1234",
  transport,
  { refname: "refs/heads/main" },
);

console.log(peers);
console.log(resolved.url);
```

Supported relay forms:

- `relay+https://relay.example.com/base?room=team-a`
- `relay+http://127.0.0.1:8787`
- `relay://relay.example.com`
- direct session URL such as `relay+https://relay.example.com/base/AbCd1234`

For direct session URLs, the library resolves to the relay proxy path `/git/<sessionId>`.
For relay base URLs, the library polls clone announcements and selects a peer by:

1. `preferredSender`
2. `preferredRepo`
3. first available sender

## Backend Contract

You can pass any backend object directly as the first argument.
The backend contract is synchronous.

```ts
import { init, writeString, add, commit } from "@mizchi/bit/lib";

const backend = {
  mkdirP(path) {},
  writeFile(path, content) {},
  writeString(path, content) {},
  removeFile(path) {},
  removeDir(path) {},
  readFile(path) {
    return new Uint8Array();
  },
  readdir(path) {
    return [];
  },
  isDir(path) {
    return false;
  },
  isFile(path) {
    return false;
  },
};

init(backend, "/repo", "main");
writeString(backend, "/repo/hello.txt", "hello\n");
add(backend, "/repo", ["hello.txt"]);
commit(backend, "/repo", "initial commit", "Example <example@example.com>");
```

Required backend methods:

- `mkdirP(path)`
- `writeFile(path, bytes)`
- `writeString(path, content)`
- `removeFile(path)`
- `removeDir(path)`
- `readFile(path)`
- `readdir(path)`
- `isDir(path)`
- `isFile(path)`

`readFile(path)` may return:

- `Uint8Array`
- `ArrayBuffer`
- `ArrayLike<number>`
- `string`

## API Notes

- Every operation takes the backend as its first argument.
- `createMemoryHost()` returns an in-memory backend for tests, workers, and browser-style environments.
- There is no `createHost()` wrapper API. Pass the backend object itself through your call sites.
- `buildCommitPayload()` returns the unsigned commit payload text you should hand to your signer.
- `commitSigned()` writes a signed commit from an armored signature string.
- `commitWithSigner()` is the ergonomic async wrapper for browser `crypto.subtle` style signers.
- `revParse()` and `showRef()` expose ref resolution helpers.
- `merge()` resolves a revision string such as `feature`, `origin/main`, or `HEAD^`.
- `rebaseStart()` / `rebaseStartWithOnto()` / `rebaseContinue()` / `rebaseAbort()` / `rebaseSkip()` expose the rebase state machine.
- `restore()` and `reset()` expose the working tree/index reset flow.
- `branchRename()` exposes `git branch -m` style renames.
- `tagList()` / `tagCreateLightweight()` / `tagCreateAnnotated()` / `tagDelete()` expose tag operations.
- `stashList()` / `stashPush()` / `stashApply()` / `stashPop()` / `stashDrop()` expose stash operations.
- `cherryPick()` exposes single-commit cherry-pick with `noCommit`, `messageSuffix`, and `signoffCommitter` options.
- `diffWorktree()` / `diffWorktreeStat()` and `diffIndex()` / `diffIndexStat()` return unified diff lines and `--stat`-style summaries.
- `listRemotes()` and `getRemoteUrl()` expose read-only remote config helpers.
- `fetch()` and `push()` are async and require an injected transport. Use `createFetchTransport(fetch)` for browser or worker `fetch`.
- `fetch()` and `push()` also understand relay signaling remotes and will resolve a peer before using Git smart HTTP.
- `relayListClonePeers()` returns `{ sender, cloneUrl, repo }[]`.
- `relayResolveRemote()` returns `{ via, url, sender, repo, sessionId }`.
- `status()` returns camelCase fields such as `stagedAdded`, `stagedDeleted`, and `untracked`.
- `branchList()` returns `{ name, commitId, isCurrent }`.
- `log()` returns `{ id, author, message, timestamp }`.
- `rm()` accepts `rm(backend, root, paths, { cached: true })`.

## Bundle Size

A minimal bundle that exercises only `init/writeString/status` measured approximately:

- raw: about `139 KB`
- gzip: about `34 KB`

A representative bundle that exercises `init/add/status/commit/branch/checkout/mv/rm/log`
measured approximately:

- raw: about `256 KB`
- gzip: about `63 KB`

Exact size depends on your entrypoint and bundler settings.
