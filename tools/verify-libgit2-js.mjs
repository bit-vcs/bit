import assert from "node:assert/strict";
import { inflateSync } from "node:zlib";

const bitGit = await import(new URL("./bit-git.mjs", import.meta.url));

function createVirtualHost() {
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  const files = new Map();
  const dirs = new Set(["/"]);

  const normalizePath = (path) => {
    if (path == null || path === "") return "/";
    let normalized = String(path).replace(/\/+/g, "/");
    if (!normalized.startsWith("/")) normalized = `/${normalized}`;
    if (normalized.length > 1 && normalized.endsWith("/")) {
      normalized = normalized.slice(0, -1);
    }
    return normalized;
  };

  const parentDir = (path) => {
    const normalized = normalizePath(path);
    if (normalized === "/") return "/";
    const index = normalized.lastIndexOf("/");
    return index <= 0 ? "/" : normalized.slice(0, index);
  };

  const baseName = (path) => {
    const normalized = normalizePath(path);
    if (normalized === "/") return "/";
    const index = normalized.lastIndexOf("/");
    return index < 0 ? normalized : normalized.slice(index + 1);
  };

  const ensureDirs = (path) => {
    const normalized = normalizePath(path);
    if (normalized === "/") {
      dirs.add("/");
      return;
    }
    const parts = normalized.split("/").filter(Boolean);
    let current = "";
    for (const part of parts) {
      current += `/${part}`;
      dirs.add(current);
    }
  };

  return {
    mkdirP(path) {
      ensureDirs(path);
    },
    writeFile(path, content) {
      const normalized = normalizePath(path);
      ensureDirs(parentDir(normalized));
      files.set(normalized, Uint8Array.from(content));
    },
    writeString(path, content) {
      this.writeFile(path, encoder.encode(String(content)));
    },
    removeFile(path) {
      const normalized = normalizePath(path);
      if (!files.delete(normalized)) {
        throw new Error(`File not found: ${normalized}`);
      }
    },
    removeDir(path) {
      const normalized = normalizePath(path);
      if (!dirs.has(normalized)) {
        throw new Error(`Directory not found: ${normalized}`);
      }
      for (const filePath of files.keys()) {
        if (parentDir(filePath) === normalized) {
          throw new Error(`Directory not empty: ${normalized}`);
        }
      }
      for (const dirPath of dirs.values()) {
        if (dirPath !== normalized && parentDir(dirPath) === normalized) {
          throw new Error(`Directory not empty: ${normalized}`);
        }
      }
      dirs.delete(normalized);
    },
    readFile(path) {
      const normalized = normalizePath(path);
      const value = files.get(normalized);
      if (!value) {
        throw new Error(`File not found: ${normalized}`);
      }
      return Uint8Array.from(value);
    },
    readdir(path) {
      const normalized = normalizePath(path);
      if (!dirs.has(normalized)) {
        throw new Error(`Directory not found: ${normalized}`);
      }
      const entries = new Set();
      for (const filePath of files.keys()) {
        if (parentDir(filePath) === normalized) {
          entries.add(baseName(filePath));
        }
      }
      for (const dirPath of dirs.values()) {
        if (dirPath !== normalized && parentDir(dirPath) === normalized) {
          entries.add(baseName(dirPath));
        }
      }
      return Array.from(entries).sort();
    },
    isDir(path) {
      return dirs.has(normalizePath(path));
    },
    isFile(path) {
      return files.has(normalizePath(path));
    },
    readString(path) {
      return decoder.decode(this.readFile(path));
    },
  };
}

function runRepoFlow(api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/hello.txt`, "hello\n");

  const beforeAdd = bitGit.status(api, root);
  assert.deepEqual(beforeAdd.untracked, ["hello.txt"]);
  assert.deepEqual(beforeAdd.stagedAdded, []);

  bitGit.add(api, root, ["hello.txt"]);

  const afterAdd = bitGit.status(api, root);
  assert.deepEqual(afterAdd.stagedAdded, ["hello.txt"]);
  assert.deepEqual(afterAdd.untracked, []);

  const commitId = bitGit.commit(api, root, "initial commit", author, 1700000000);
  assert.equal(commitId.length, 40);

  const clean = bitGit.status(api, root);
  assert.deepEqual(clean.stagedAdded, []);
  assert.deepEqual(clean.untracked, []);
  assert.deepEqual(clean.unstagedModified, []);

  bitGit.checkoutB(api, root, "feature");

  const branches = bitGit.branchList(api, root);
  assert.ok(branches.some((branch) => branch.name === "main"));
  assert.ok(branches.some((branch) => branch.name === "feature" && branch.isCurrent));

  const logEntries = bitGit.log(api, root, 10);
  assert.equal(logEntries.length, 1);
  assert.equal(logEntries[0].message, "initial commit");
  assert.equal(logEntries[0].author, author);

  const head = bitGit.readString(api, `${root}/.git/HEAD`);
  assert.equal(head, "ref: refs/heads/feature\n");

  return { commitId, branches, logEntries, head };
}

function readLooseCommitText(backend, root, commitId) {
  const compressed = backend.readFile(
    `${root}/.git/objects/${commitId.slice(0, 2)}/${commitId.slice(2)}`,
  );
  const raw = inflateSync(Buffer.from(compressed));
  const headerEnd = raw.indexOf(0);
  assert.notEqual(headerEnd, -1);
  return raw.subarray(headerEnd + 1).toString("utf8");
}

async function runSignedCommitFlow(api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/signed.txt`, "signed\n");
  bitGit.add(api, root, ["signed.txt"]);

  const payload = bitGit.buildCommitPayload(
    api,
    root,
    "signed commit",
    author,
    1700000001,
  );
  assert.match(payload, /^tree [0-9a-f]{40}\n/m);
  assert.ok(!payload.includes("gpgsig "));

  let signerPayload = null;
  const commitId = await bitGit.commitWithSigner(
    api,
    root,
    "signed commit",
    author,
    async (payloadToSign) => {
      signerPayload = payloadToSign;
      return [
        "-----BEGIN TEST SIGNATURE-----",
        "abc123",
        "-----END TEST SIGNATURE-----",
      ].join("\n");
    },
    1700000001,
  );
  assert.equal(signerPayload, payload);

  const commitText = readLooseCommitText(api, root, commitId);
  assert.ok(
    commitText.includes(
      "gpgsig -----BEGIN TEST SIGNATURE-----\n abc123\n -----END TEST SIGNATURE-----\n",
    ),
  );

  const logEntries = bitGit.log(api, root, 10);
  assert.equal(logEntries[0].message, "signed commit");

  return { commitId, payload, commitText };
}

function runMergeFlow(api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/file.txt`, "line1\nline2\nline3\nline4\n");
  bitGit.add(api, root, ["file.txt"]);
  bitGit.commit(api, root, "base", author, 1700000100);

  bitGit.checkoutB(api, root, "feature");
  bitGit.writeString(api, `${root}/file.txt`, "line1\nfeature\nline3\nline4\n");
  bitGit.add(api, root, ["file.txt"]);
  bitGit.commit(api, root, "feature", author, 1700000101);

  bitGit.checkout(api, root, "main");
  bitGit.writeString(api, `${root}/file.txt`, "line1\nline2\nline3\nmain\n");
  bitGit.add(api, root, ["file.txt"]);
  bitGit.commit(api, root, "main", author, 1700000102);

  const mergeResult = bitGit.merge(
    api,
    root,
    "feature",
    "merge feature",
    author,
    1700000103,
  );
  assert.equal(mergeResult.status, "merged");
  assert.equal(bitGit.readString(api, `${root}/file.txt`), "line1\nfeature\nline3\nmain\n");
  return mergeResult;
}

function runRebaseFlow(api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/a.txt`, "A\n");
  bitGit.add(api, root, ["a.txt"]);
  bitGit.commit(api, root, "A", author, 1700000200);

  bitGit.checkoutB(api, root, "topic");
  bitGit.writeString(api, `${root}/d.txt`, "D\n");
  bitGit.add(api, root, ["d.txt"]);
  bitGit.commit(api, root, "D", author, 1700000201);

  bitGit.checkout(api, root, "main");
  bitGit.writeString(api, `${root}/b.txt`, "B\n");
  bitGit.add(api, root, ["b.txt"]);
  bitGit.commit(api, root, "B", author, 1700000202);

  bitGit.checkout(api, root, "topic");
  const rebaseResult = bitGit.rebaseStart(api, root, "main");
  assert.equal(rebaseResult.status, "complete");
  assert.equal(bitGit.readString(api, `${root}/b.txt`), "B\n");
  assert.equal(bitGit.readString(api, `${root}/d.txt`), "D\n");
  return rebaseResult;
}

function runRefsTagsResetFlow(api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/a.txt`, "one\n");
  bitGit.add(api, root, ["a.txt"]);
  const first = bitGit.commit(api, root, "first", author, 1700000400);

  assert.equal(bitGit.revParse(api, root, "HEAD"), first);
  const refs = bitGit.showRef(api, root);
  assert.ok(refs.some((refInfo) => refInfo.name === "refs/heads/main" && refInfo.id === first));

  bitGit.writeString(
    api,
    `${root}/.git/config`,
    "[remote \"origin\"]\n\turl = https://example.com/repo.git\n",
  );
  assert.deepEqual(bitGit.listRemotes(api, root), ["origin"]);
  assert.equal(bitGit.getRemoteUrl(api, root, "origin"), "https://example.com/repo.git");

  bitGit.branchCreate(api, root, "topic");
  bitGit.branchRename(api, root, "topic", "renamed", {
    author: "Tester",
    email: "tester@example.com",
    timestampSec: 1700000401,
  });
  const branches = bitGit.branchList(api, root);
  assert.ok(branches.some((branch) => branch.name === "renamed"));
  assert.ok(!branches.some((branch) => branch.name === "topic"));

  bitGit.tagCreateLightweight(api, root, "v1", "HEAD");
  bitGit.tagCreateAnnotated(
    api,
    root,
    "release",
    "HEAD",
    "release tag",
    author,
    1700000402,
  );
  const tags = bitGit.tagList(api, root);
  assert.equal(tags.length, 2);
  assert.ok(tags.includes("v1"));
  assert.ok(tags.includes("release"));
  assert.equal(bitGit.revParse(api, root, "release^{commit}"), first);
  bitGit.tagDelete(api, root, "v1");
  assert.deepEqual(bitGit.tagList(api, root), ["release"]);

  bitGit.writeString(api, `${root}/a.txt`, "working\n");
  bitGit.restore(api, root, ["a.txt"]);
  assert.equal(bitGit.readString(api, `${root}/a.txt`), "one\n");

  bitGit.writeString(api, `${root}/a.txt`, "two\n");
  bitGit.add(api, root, ["a.txt"]);
  bitGit.commit(api, root, "second", author, 1700000403);
  assert.equal(bitGit.reset(api, root, "HEAD^", "hard"), first);
  assert.equal(bitGit.revParse(api, root, "HEAD"), first);
  assert.equal(bitGit.readString(api, `${root}/a.txt`), "one\n");

  return { first, refs, branches, tags };
}

async function runStashDiffCherryPickFlow(api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/a.txt`, "base\n");
  bitGit.add(api, root, ["a.txt"]);
  bitGit.commit(api, root, "base", author, 1700000500);

  bitGit.writeString(api, `${root}/a.txt`, "working\n");
  const worktreeDiff = await bitGit.diffWorktree(api, root);
  assert.ok(worktreeDiff.includes("diff --git a/a.txt b/a.txt"));
  const worktreeStat = await bitGit.diffWorktreeStat(api, root);
  assert.ok(worktreeStat[0]?.includes("a.txt"));

  const stashId = await bitGit.stashPush(api, root, "save working", author, 1700000501);
  assert.equal(typeof stashId, "string");
  assert.equal(stashId.length, 40);
  const stashEntries = bitGit.stashList(api, root);
  assert.equal(stashEntries.length, 1);
  assert.match(stashEntries[0].message, /save working/);
  assert.equal(bitGit.readString(api, `${root}/a.txt`), "base\n");

  bitGit.stashApply(api, root, 0);
  assert.equal(bitGit.readString(api, `${root}/a.txt`), "working\n");
  bitGit.add(api, root, ["a.txt"]);
  const indexDiff = bitGit.diffIndex(api, root);
  assert.ok(indexDiff.includes("diff --git a/a.txt b/a.txt"));
  const indexStat = bitGit.diffIndexStat(api, root);
  assert.ok(indexStat[indexStat.length - 1]?.includes("1 file(s) changed"));
  bitGit.stashDrop(api, root, 0);
  assert.equal(bitGit.stashList(api, root).length, 0);

  const cherryRoot = `${root}-pick`;
  bitGit.init(api, cherryRoot, "main");
  bitGit.writeString(api, `${cherryRoot}/base.txt`, "base\n");
  bitGit.add(api, cherryRoot, ["base.txt"]);
  bitGit.commit(api, cherryRoot, "base", author, 1700000600);
  bitGit.checkoutB(api, cherryRoot, "feature");
  bitGit.writeString(api, `${cherryRoot}/side.txt`, "side\n");
  bitGit.add(api, cherryRoot, ["side.txt"]);
  bitGit.commit(api, cherryRoot, "side", author, 1700000601);
  bitGit.checkout(api, cherryRoot, "main");
  const cherryPickResult = bitGit.cherryPick(api, cherryRoot, "feature", author, {
    timestampSec: 1700000602,
  });
  assert.equal(cherryPickResult.status, "success");
  assert.equal(cherryPickResult.commitId?.length, 40);
  assert.equal(bitGit.readString(api, `${cherryRoot}/side.txt`), "side\n");

  return { stashId, stashEntries, cherryPickResult };
}

const memoryApi = bitGit.createMemoryHost();
const memoryResult = runRepoFlow(
  memoryApi,
  "/repo-memory",
  "Verifier <verifier@example.com>",
);

const customBackend = createVirtualHost();
const customResult = runRepoFlow(
  customBackend,
  "/repo-custom",
  "Custom Host <custom@example.com>",
);

const signedResult = await runSignedCommitFlow(
  memoryApi,
  "/repo-signed",
  "Signer <signer@example.com>",
);
const mergeResult = runMergeFlow(
  memoryApi,
  "/repo-merge",
  "Merger <merger@example.com>",
);
const rebaseResult = runRebaseFlow(
  memoryApi,
  "/repo-rebase",
  "Rebaser <rebaser@example.com>",
);
const refsTagsResetResult = runRefsTagsResetFlow(
  memoryApi,
  "/repo-refs",
  "Refs <refs@example.com>",
);
const stashDiffCherryPickResult = await runStashDiffCherryPickFlow(
  memoryApi,
  "/repo-stash",
  "Stash <stash@example.com>",
);

assert.equal(typeof bitGit.createFetchTransport, "function");
assert.equal(typeof bitGit.fetch, "function");
assert.equal(typeof bitGit.push, "function");

bitGit.destroyHost(memoryApi);
bitGit.destroyHost(customBackend);

console.log(JSON.stringify(
  {
    memoryResult,
    customResult,
    signedResult,
    mergeResult,
    rebaseResult,
    refsTagsResetResult,
    stashDiffCherryPickResult,
  },
  null,
  2,
));
