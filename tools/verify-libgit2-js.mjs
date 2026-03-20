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

bitGit.destroyHost(memoryApi);
bitGit.destroyHost(customBackend);

console.log(JSON.stringify(
  {
    memoryResult,
    customResult,
    signedResult,
  },
  null,
  2,
));
