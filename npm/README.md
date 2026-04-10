# @mizchi/bit

Experimental Git implementation in MoonBit.

This package exposes:

- `bit` CLI
- a tree-shakable JS library API at `@mizchi/bit`

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
  type BitBackend,
  branchList,
  buildCommitPayload,
  commit,
  commitAmend,
  commitSignedChecked,
  commitWithSigner,
  createFetchTransport,
  fetch,
  init,
  listRemotesVerbose,
  log,
  merge,
  relayListClonePeers,
  relayResolveRemote,
  push,
  rebaseStart,
  resolveSshEd25519PublicKey,
  signGitPayloadSshEd25519,
  status,
  statusText,
  switchBranch,
  verifyCommitSshEd25519,
  verifyGitPayloadSshEd25519,
  writeString,
} from "@mizchi/bit";

declare const backend: BitBackend;

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

switchBranch(backend, "/repo", "feature", { create: true });
const amendedCommitId = commitAmend(
  backend,
  "/repo",
  "amended commit",
  "Example <example@example.com>",
  1700000002,
);
console.log(await statusText(backend, "/repo"));
console.log(listRemotesVerbose(backend, "/repo"));

const payload = buildCommitPayload(
  backend,
  "/repo",
  "signed commit",
  "Example <example@example.com>",
  1700000001,
);
const privateKeyPem = [
  "-----BEGIN PRIVATE KEY-----",
  "...",
  "-----END PRIVATE KEY-----",
].join("\n");
const publicKey = await resolveSshEd25519PublicKey(privateKeyPem);
const signature = await signGitPayloadSshEd25519(privateKeyPem, payload);

const signedCommitId = commitSignedChecked(
  backend,
  "/repo",
  "signed commit",
  "Example <example@example.com>",
  payload,
  signature,
  1700000001,
);

const signedCommitIdFromSigner = await commitWithSigner(
  backend,
  "/repo",
  "signed commit",
  "Example <example@example.com>",
  (payloadToSign) => signGitPayloadSshEd25519(privateKeyPem, payloadToSign),
  1700000001,
);

console.log(payload);
console.log(signedCommitId);
console.log(signedCommitIdFromSigner);
console.log(await verifyGitPayloadSshEd25519(publicKey, payload, signature));
console.log(await verifyCommitSshEd25519(backend, "/repo", "HEAD", publicKey));

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
} from "@mizchi/bit";

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
import { init, writeString, add, commit } from "@mizchi/bit";

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
- `createMemoryBackend()` returns an in-memory backend for tests, workers, and browser-style environments.
- There is no `createHost()` wrapper API. Pass the backend object itself through your call sites.
- `buildCommitPayload()` returns the unsigned commit payload text you should hand to your signer.
- `commitSigned()` writes a signed commit from an armored signature string.
- `commitSignedChecked()` writes a signed commit only if the supplied payload still matches the current index/tree state.
- `commitWithSigner()` is the ergonomic async wrapper that signs `buildCommitPayload()` output and finalizes through `commitSignedChecked()`.
- `resolveSshEd25519PublicKey()` derives an OpenSSH public key line from a PKCS#8 Ed25519 private key PEM.
- `signGitPayloadSshEd25519()` signs commit payload text and returns Git-compatible `-----BEGIN SSH SIGNATURE-----` armor.
- `verifyGitPayloadSshEd25519()` verifies a payload/signature pair against an OpenSSH `ssh-ed25519 ...` public key line.
- `verifyCommitSshEd25519()` extracts `gpgsig` from a commit and verifies it against an OpenSSH `ssh-ed25519 ...` public key line.
- JS signed-commit support currently targets `SSH + Ed25519 + commit + SHA-1 repo` only.
- JS verification is cryptographic verification against the supplied public key only. Git trust policy such as `allowedSignersFile`, principals, and revocation is not applied.
- `commitAmend()` exposes `git commit --amend` style history replacement.
- `revParse()` and `showRef()` expose ref resolution helpers.
- `merge()` resolves a revision string such as `feature`, `origin/main`, or `HEAD^`.
- `rebaseStart()` / `rebaseStartWithOnto()` / `rebaseContinue()` / `rebaseAbort()` / `rebaseSkip()` expose the rebase state machine.
- `statusText()` exposes the human-readable porcelain status summary.
- `restore()` and `reset()` expose the working tree/index reset flow.
- `switchBranch()` exposes branch switching with `{ create, checkoutFiles }`.
- `branchRename()` exposes `git branch -m` style renames.
- `tagList()` / `tagCreateLightweight()` / `tagCreateAnnotated()` / `tagDelete()` expose tag operations.
- `stashList()` / `stashPush()` / `stashApply()` / `stashPop()` / `stashDrop()` expose stash operations.
- `cherryPick()` exposes single-commit cherry-pick with `noCommit`, `messageSuffix`, and `signoffCommitter` options.
- `diffWorktree()` / `diffWorktreeStat()` and `diffIndex()` / `diffIndexStat()` return unified diff lines and `--stat`-style summaries.
- `listRemotes()`, `listRemotesVerbose()`, and `getRemoteUrl()` expose read-only remote config helpers.
- `sparseCheckoutInit()` / `sparseCheckoutSet()` / `sparseCheckoutAdd()` / `sparseCheckoutDisable()` / `sparseCheckoutReapply()` expose sparse checkout control.
- `sparseCheckoutEnabled()`, `sparseCheckoutConeEnabled()`, `sparseCheckoutPatterns()`, and `sparseCheckoutDisplayPatterns()` expose sparse checkout state.
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
