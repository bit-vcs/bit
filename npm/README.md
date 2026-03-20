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
  init,
  log,
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
```

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
- `status()` returns camelCase fields such as `stagedAdded`, `stagedDeleted`, and `untracked`.
- `branchList()` returns `{ name, commitId, isCurrent }`.
- `log()` returns `{ id, author, message, timestamp }`.
- `rm()` accepts `rm(backend, root, paths, { cached: true })`.

## Bundle Size

A minimal bundle that exercises only `init/writeString/status` measured approximately:

- raw: about `132 KB`
- gzip: about `33 KB`

A representative bundle that exercises `init/add/status/commit/branch/checkout/mv/rm/log`
measured approximately:

- raw: about `250 KB`
- gzip: about `62 KB`

Exact size depends on your entrypoint and bundler settings.
