import assert from "node:assert/strict";
import { inflateSync } from "node:zlib";
import { pathToFileURL } from "node:url";

const defaultBitGit = await import(new URL("./bit-git.mjs", import.meta.url));

const decodeHex = (hex) => Uint8Array.from(
  String(hex ?? "").match(/../g)?.map((pair) => Number.parseInt(pair, 16)) ?? [],
);

const cloneFixtureAdvV2Hex = "3030306576657273696f6e20320a303031636167656e743d6769742f322e35302e312d44617277696e0a303031336c732d726566733d756e626f726e0a3030323066657463683d7368616c6c6f7720776169742d666f722d646f6e650a303031327365727665722d6f7074696f6e0a303031376f626a6563742d666f726d61743d736861310a30303030";
const cloneFixtureLsrefsHex = "303035303330633966323038616363373630313737336132396165663339343135376164663936306431303420484541442073796d7265662d7461726765743a726566732f68656164732f6d61696e0a303033643330633966323038616363373630313737336132396165663339343135376164663936306431303420726566732f68656164732f6d61696e0a30303030";
const cloneFixtureFetchHex = "303030647061636b66696c650a30306435015041434b00000002000000039b09789c95cb310ac3300c40d1dda7f05e28b21ccb319492ab288ad208ea0682baf4f4cd15327d78f0fd508dccdc4874c1a57192512b4aa1194b66505cb58eb9e555e71af8ebdb7ec46e3fd92c3ece0e304cafcef6becbde9f31556a2513258c376800e1d46eee7a690af6310f7f8ae52e13a502789c33343030333151c848cdc9c9d72ba9286138c768a6caccbde2f64ab6ef61d3eae7cd593cc5cd0b00df740dbf36789ccb48cdc9c9e70200084b021f62c7bf336ea966f094470f354a76a0f737e13d30303036017a30303030";
const cloneFixtureCommit = "30c9f208acc7601773a29aef394157adf960d104";
const sshTestPrivateKey = [
  "-----BEGIN PRIVATE KEY-----",
  "MC4CAQAwBQYDK2VwBCIEIEYOzKBrnjy/eCL5x9n4fAniBKTxut5of1q69fXuIjc6",
  "-----END PRIVATE KEY-----",
].join("\n");
const sshWrongPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKrq4Q6Q5lM6R5i2uY1v3f6hM1dYkN0zPpLxjW0l8M4W wrong@example.com";

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

function runRepoFlow(bitGit, api, root, author) {
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

async function runSignedCommitFlow(bitGit, api, root, author) {
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

async function runSshSignatureFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/signed.txt`, "signed\n");
  bitGit.add(api, root, ["signed.txt"]);

  const payload = bitGit.buildCommitPayload(
    api,
    root,
    "signed ssh commit",
    author,
    1700000002,
  );
  const publicKey = await bitGit.resolveSshEd25519PublicKey(sshTestPrivateKey);
  assert.match(publicKey, /^ssh-ed25519 /);

  const signature = await bitGit.signGitPayloadSshEd25519(
    sshTestPrivateKey,
    payload,
  );
  assert.match(signature, /BEGIN SSH SIGNATURE/);

  assert.equal(
    await bitGit.verifyGitPayloadSshEd25519(publicKey, payload, signature),
    true,
  );
  assert.equal(
    await bitGit.verifyGitPayloadSshEd25519(publicKey, `${payload}tampered`, signature),
    false,
  );

  const commitId = bitGit.commitSignedChecked(
    api,
    root,
    "signed ssh commit",
    author,
    payload,
    signature,
    1700000002,
  );
  const commitText = readLooseCommitText(api, root, commitId);
  assert.ok(commitText.includes("gpgsig -----BEGIN SSH SIGNATURE-----\n"));

  assert.equal(
    await bitGit.verifyCommitSshEd25519(api, root, "HEAD", publicKey),
    true,
  );
  assert.equal(
    await bitGit.verifyCommitSshEd25519(api, root, "HEAD", sshWrongPublicKey),
    false,
  );

  return { commitId, payload, publicKey, signature };
}

function runMergeFlow(bitGit, api, root, author) {
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

function runRebaseFlow(bitGit, api, root, author) {
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
  const rebaseResult = bitGit.rebase(api, root, "main");
  assert.equal(rebaseResult.status, "complete");
  assert.equal(bitGit.readString(api, `${root}/b.txt`), "B\n");
  assert.equal(bitGit.readString(api, `${root}/d.txt`), "D\n");
  return rebaseResult;
}

function runRefsTagsResetFlow(bitGit, api, root, author) {
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

async function runStatusAmendSwitchRemoteFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/a.txt`, "one\n");

  const initialStatusText = await bitGit.statusText(api, root);
  assert.ok(initialStatusText.includes("On branch main"));
  assert.ok(initialStatusText.includes("No commits yet"));

  bitGit.add(api, root, ["a.txt"]);
  const stagedStatusText = await bitGit.statusText(api, root);
  assert.ok(stagedStatusText.includes("Changes to be committed"));
  assert.ok(stagedStatusText.includes("staged: a.txt"));

  bitGit.commit(api, root, "first", author, 1700000450);
  bitGit.switchBranch(api, root, "feature", { create: true });
  assert.equal(bitGit.readString(api, `${root}/.git/HEAD`), "ref: refs/heads/feature\n");

  bitGit.writeString(api, `${root}/a.txt`, "feature\n");
  bitGit.add(api, root, ["a.txt"]);
  bitGit.commit(api, root, "feature", author, 1700000451);

  const originalHead = bitGit.revParse(api, root, "HEAD");
  const amendedHead = bitGit.commitAmend(
    api,
    root,
    "feature amended",
    author,
    1700000452,
    {
      committer: author,
      committerTimestampSec: 1700000452,
    },
  );
  assert.equal(typeof amendedHead, "string");
  assert.equal(amendedHead.length, 40);
  assert.notEqual(amendedHead, originalHead);
  assert.equal(bitGit.log(api, root, 1)[0]?.message, "feature amended");

  bitGit.switchBranch(api, root, "main");
  assert.equal(bitGit.readString(api, `${root}/a.txt`), "one\n");

  bitGit.writeString(
    api,
    `${root}/.git/config`,
    "[remote \"origin\"]\n\turl = https://example.com/fetch.git\n\tpushurl = https://example.com/push.git\n",
  );
  const remotes = bitGit.listRemotesVerbose(api, root);
  assert.equal(remotes.length, 2);
  assert.equal(remotes[0]?.name, "origin");
  assert.match(remotes[0]?.value ?? "", /\(fetch\)/);
  assert.match(remotes[1]?.value ?? "", /\(push\)/);

  return { amendedHead, remotes };
}

function runSparseCheckoutFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/keep/file.txt`, "keep\n");
  bitGit.writeString(api, `${root}/skip/file.txt`, "skip\n");
  bitGit.add(api, root, ["keep/file.txt", "skip/file.txt"]);
  bitGit.commit(api, root, "base", author, 1700000460);

  bitGit.sparseCheckoutInit(api, root, false);
  bitGit.sparseCheckoutSet(api, root, ["keep"]);
  assert.equal(bitGit.sparseCheckoutEnabled(api, root), true);
  assert.equal(bitGit.sparseCheckoutConeEnabled(api, root), false);
  assert.deepEqual(bitGit.sparseCheckoutDisplayPatterns(api, root), ["keep"]);
  assert.equal(bitGit.readString(api, `${root}/keep/file.txt`), "keep\n");
  assert.ok(bitGit.status(api, root).unstagedDeleted.includes("skip/file.txt"));

  bitGit.sparseCheckoutAdd(api, root, ["skip"]);
  const patternsAfterAdd = bitGit.sparseCheckoutDisplayPatterns(api, root);
  assert.ok(patternsAfterAdd.includes("keep"));
  assert.ok(patternsAfterAdd.includes("skip"));
  bitGit.sparseCheckoutReapply(api, root);
  assert.equal(bitGit.readString(api, `${root}/skip/file.txt`), "skip\n");

  bitGit.sparseCheckoutDisable(api, root);
  assert.equal(bitGit.sparseCheckoutEnabled(api, root), false);
  assert.ok(bitGit.sparseCheckoutPatterns(api, root).length > 0);
  assert.equal(bitGit.readString(api, `${root}/skip/file.txt`), "skip\n");

  return { patternsAfterAdd };
}

async function runStashDiffCherryPickFlow(bitGit, api, root, author) {
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

function runFileOpsFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  assert.deepEqual(bitGit.statusPorcelain(api, root), []);

  bitGit.writeString(api, `${root}/README.md`, "# repo\n");
  assert.ok(bitGit.statusPorcelain(api, root).includes("?? README.md"));

  bitGit.add(api, root, ["README.md"]);
  assert.ok(bitGit.statusPorcelain(api, root).includes("A  README.md"));
  bitGit.commit(api, root, "initial commit", author, 1700000700);
  assert.deepEqual(bitGit.statusPorcelain(api, root), []);

  bitGit.branchCreate(api, root, "topic");
  assert.ok(bitGit.branchList(api, root).some((branch) => branch.name === "topic"));
  bitGit.branchDelete(api, root, "topic");
  assert.ok(!bitGit.branchList(api, root).some((branch) => branch.name === "topic"));

  bitGit.writeString(api, `${root}/notes.txt`, "notes\n");
  bitGit.add(api, root, ["notes.txt"]);
  bitGit.commit(api, root, "add notes", author, 1700000701);

  bitGit.mv(api, root, "notes.txt", "memo.txt");
  const afterMove = bitGit.status(api, root);
  assert.ok(afterMove.stagedAdded.includes("memo.txt"));
  assert.ok(afterMove.stagedDeleted.includes("notes.txt"));
  bitGit.commit(api, root, "rename notes", author, 1700000702);

  bitGit.rm(api, root, ["memo.txt"]);
  const afterRm = bitGit.status(api, root);
  assert.ok(afterRm.stagedDeleted.includes("memo.txt"));
  bitGit.commit(api, root, "remove memo", author, 1700000703);

  bitGit.writeString(api, `${root}/cached.txt`, "cached\n");
  bitGit.add(api, root, ["cached.txt"]);
  bitGit.commit(api, root, "add cached", author, 1700000704);
  bitGit.rm(api, root, ["cached.txt"], { cached: true });
  assert.equal(bitGit.readString(api, `${root}/cached.txt`), "cached\n");
  assert.ok(bitGit.status(api, root).stagedDeleted.includes("cached.txt"));

  return { afterMove, afterRm };
}

function runDirectSignedCommitFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/signed.txt`, "signed\n");
  bitGit.add(api, root, ["signed.txt"]);
  const commitId = bitGit.commitSigned(
    api,
    root,
    "signed direct",
    author,
    "-----BEGIN TEST SIGNATURE-----\nabc456\n-----END TEST SIGNATURE-----\n",
    1700000800,
  );
  const commitText = readLooseCommitText(api, root, commitId);
  assert.match(commitText, /gpgsig -----BEGIN TEST SIGNATURE-----/);
  assert.match(commitText, /abc456/);
  return { commitId, commitText };
}

function setupConflictRepo(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/file.txt`, "base\n");
  bitGit.add(api, root, ["file.txt"]);
  const baseId = bitGit.commit(api, root, "base", author, 1700000900);

  bitGit.checkoutB(api, root, "topic");
  bitGit.writeString(api, `${root}/file.txt`, "topic\n");
  bitGit.add(api, root, ["file.txt"]);
  const topicId = bitGit.commit(api, root, "topic", author, 1700000901);

  bitGit.checkout(api, root, "main");
  bitGit.writeString(api, `${root}/file.txt`, "main\n");
  bitGit.add(api, root, ["file.txt"]);
  const mainId = bitGit.commit(api, root, "main", author, 1700000902);

  bitGit.checkout(api, root, "topic");
  return { baseId, topicId, mainId };
}

function runRebaseOntoFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/a.txt`, "A\n");
  bitGit.add(api, root, ["a.txt"]);
  const commitA = bitGit.commit(api, root, "A", author, 1700001000);

  bitGit.branchCreate(api, root, "topic");
  bitGit.checkout(api, root, "topic");
  bitGit.writeString(api, `${root}/d.txt`, "D\n");
  bitGit.add(api, root, ["d.txt"]);
  bitGit.commit(api, root, "D", author, 1700001001);
  bitGit.writeString(api, `${root}/e.txt`, "E\n");
  bitGit.add(api, root, ["e.txt"]);
  bitGit.commit(api, root, "E", author, 1700001002);

  bitGit.checkout(api, root, "main");
  bitGit.writeString(api, `${root}/b.txt`, "B\n");
  bitGit.add(api, root, ["b.txt"]);
  bitGit.commit(api, root, "B", author, 1700001003);
  bitGit.writeString(api, `${root}/c.txt`, "C\n");
  bitGit.add(api, root, ["c.txt"]);
  const commitC = bitGit.commit(api, root, "C", author, 1700001004);

  bitGit.checkout(api, root, "topic");
  const result = bitGit.rebaseStartWithOnto(api, root, commitC, commitA);
  assert.equal(result.status, "complete");
  assert.equal(bitGit.readString(api, `${root}/b.txt`), "B\n");
  assert.equal(bitGit.readString(api, `${root}/c.txt`), "C\n");
  assert.equal(bitGit.readString(api, `${root}/d.txt`), "D\n");
  assert.equal(bitGit.readString(api, `${root}/e.txt`), "E\n");
  return result;
}

function runRebaseControlFlow(bitGit, api, root, author) {
  const continueRoot = `${root}-continue`;
  setupConflictRepo(bitGit, api, continueRoot, author);
  const continueStart = bitGit.rebase(api, continueRoot, "main");
  assert.equal(continueStart.status, "conflict");
  assert.deepEqual(continueStart.conflicts, ["file.txt"]);
  bitGit.writeString(api, `${continueRoot}/file.txt`, "resolved\n");
  bitGit.add(api, continueRoot, ["file.txt"]);
  const continueResult = bitGit.rebaseContinue(api, continueRoot);
  assert.equal(continueResult.status, "complete");
  assert.equal(bitGit.readString(api, `${continueRoot}/file.txt`), "resolved\n");

  const abortRoot = `${root}-abort`;
  const abortRepo = setupConflictRepo(bitGit, api, abortRoot, author);
  const abortStart = bitGit.rebaseStart(api, abortRoot, "main");
  assert.equal(abortStart.status, "conflict");
  bitGit.rebaseAbort(api, abortRoot);
  assert.equal(bitGit.revParse(api, abortRoot, "HEAD"), abortRepo.topicId);
  assert.equal(bitGit.readString(api, `${abortRoot}/file.txt`), "topic\n");

  const skipRoot = `${root}-skip`;
  const skipRepo = setupConflictRepo(bitGit, api, skipRoot, author);
  const skipStart = bitGit.rebaseStart(api, skipRoot, "main");
  assert.equal(skipStart.status, "conflict");
  const skipResult = bitGit.rebaseSkip(api, skipRoot);
  assert.equal(skipResult.status, "complete");
  assert.equal(skipResult.commitId, skipRepo.mainId);
  assert.equal(bitGit.readString(api, `${skipRoot}/file.txt`), "main\n");

  return { continueResult, abortStart, skipResult };
}

async function runStashPopFlow(bitGit, api, root, author) {
  bitGit.init(api, root, "main");
  bitGit.writeString(api, `${root}/a.txt`, "base\n");
  bitGit.add(api, root, ["a.txt"]);
  bitGit.commit(api, root, "base", author, 1700001100);

  bitGit.writeString(api, `${root}/a.txt`, "working\n");
  const stashId = await bitGit.stashPush(api, root, "stash for pop", author, 1700001101);
  assert.equal(stashId.length, 40);
  assert.equal(bitGit.stashList(api, root).length, 1);
  bitGit.stashPop(api, root, 0);
  assert.equal(bitGit.stashList(api, root).length, 0);
  assert.equal(bitGit.readString(api, `${root}/a.txt`), "working\n");
  return { stashId };
}

async function runTransportHelperFlow(bitGit) {
  const calls = [];
  const transport = bitGit.createFetchTransport(async (url, init = {}) => {
    calls.push({
      url,
      method: init.method ?? "GET",
      headers: init.headers ?? {},
      body: init.body ? Array.from(new Uint8Array(init.body)) : [],
    });
    if ((init.method ?? "GET") === "GET") {
      return new Response("get-body", { status: 201 });
    }
    return new Response(new Uint8Array([9, 8, 7]), { status: 202 });
  });

  const getResult = await transport.get("https://example.com/info", { Accept: "x-test" });
  assert.equal(getResult.status, 201);
  assert.equal(new TextDecoder().decode(getResult.body), "get-body");

  const postResult = await transport.post(
    "https://example.com/post",
    new Uint8Array([1, 2, 3]),
    { "Content-Type": "application/octet-stream" },
  );
  assert.equal(postResult.status, 202);
  assert.deepEqual(Array.from(postResult.body), [9, 8, 7]);
  assert.deepEqual(calls, [
    {
      url: "https://example.com/info",
      method: "GET",
      headers: { Accept: "x-test" },
      body: [],
    },
    {
      url: "https://example.com/post",
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: [1, 2, 3],
    },
  ]);

  return { calls };
}

async function runCloneFlow(bitGit) {
  const backend = bitGit.createMemoryBackend();
  const decoder = new TextDecoder();
  const calls = [];
  const transport = {
    async get(url, headers) {
      calls.push({ method: "GET", url, headers });
      return {
        status: 200,
        body: decodeHex(cloneFixtureAdvV2Hex),
      };
    },
    async post(url, body, headers) {
      const requestText = decoder.decode(body ?? new Uint8Array());
      calls.push({ method: "POST", url, headers, requestText });
      if (requestText.includes("command=ls-refs")) {
        return {
          status: 200,
          body: decodeHex(cloneFixtureLsrefsHex),
        };
      }
      if (requestText.includes("command=fetch") || requestText.includes("want ")) {
        return {
          status: 200,
          body: decodeHex(cloneFixtureFetchHex),
        };
      }
      throw new Error(`unexpected clone request: ${requestText}`);
    },
  };

  try {
    const result = await bitGit.clone(
      backend,
      "/repo-clone",
      "git@github.com:user/repo.git",
      transport,
    );
    assert.equal(result.status, "cloned");
    assert.equal(result.commitId, cloneFixtureCommit);
    assert.equal(result.refname, "refs/heads/main");
    assert.equal(bitGit.readString(backend, "/repo-clone/hello.txt"), "hello\n");
    assert.equal(
      bitGit.getRemoteUrl(backend, "/repo-clone", "origin"),
      "git@github.com:user/repo.git",
    );
    assert.equal(
      calls.some((call) => (
        call.url === "https://github.com/user/repo/info/refs?service=git-upload-pack"
      )),
      true,
    );
    assert.equal(
      calls.some((call) => call.url === "https://github.com/user/repo/git-upload-pack"),
      true,
    );
    const requestTexts = calls
      .filter((call) => call.method === "POST")
      .map((call) => call.requestText ?? "");
    assert.ok(requestTexts.some((text) => text.includes("command=ls-refs")));
    assert.ok(requestTexts.some((text) => text.includes("command=fetch")));
    return { result, calls };
  } finally {
    bitGit.destroyBackend(backend);
  }
}

export async function verifyBitGitModule(bitGit = defaultBitGit) {
  const memoryApi = bitGit.createMemoryBackend();
  const customBackend = createVirtualHost();
  try {
    const memoryResult = runRepoFlow(
      bitGit,
      memoryApi,
      "/repo-memory",
      "Verifier <verifier@example.com>",
    );

    const customResult = runRepoFlow(
      bitGit,
      customBackend,
      "/repo-custom",
      "Custom Host <custom@example.com>",
    );

    const signedResult = await runSignedCommitFlow(
      bitGit,
      memoryApi,
      "/repo-signed",
      "Signer <signer@example.com>",
    );
    const sshSignatureResult = await runSshSignatureFlow(
      bitGit,
      memoryApi,
      "/repo-signed-ssh",
      "SSH Signer <signer@example.com>",
    );
    const directSignedResult = runDirectSignedCommitFlow(
      bitGit,
      memoryApi,
      "/repo-signed-direct",
      "Signer <signer@example.com>",
    );
    const mergeResult = runMergeFlow(
      bitGit,
      memoryApi,
      "/repo-merge",
      "Merger <merger@example.com>",
    );
    const rebaseResult = runRebaseFlow(
      bitGit,
      memoryApi,
      "/repo-rebase",
      "Rebaser <rebaser@example.com>",
    );
    const rebaseOntoResult = runRebaseOntoFlow(
      bitGit,
      memoryApi,
      "/repo-rebase-onto",
      "Rebase Onto <onto@example.com>",
    );
    const rebaseControlResult = runRebaseControlFlow(
      bitGit,
      memoryApi,
      "/repo-rebase-control",
      "Rebase Control <control@example.com>",
    );
    const refsTagsResetResult = runRefsTagsResetFlow(
      bitGit,
      memoryApi,
      "/repo-refs",
      "Refs <refs@example.com>",
    );
    const statusAmendSwitchRemoteResult = await runStatusAmendSwitchRemoteFlow(
      bitGit,
      memoryApi,
      "/repo-status",
      "Status <status@example.com>",
    );
    const fileOpsResult = runFileOpsFlow(
      bitGit,
      memoryApi,
      "/repo-files",
      "Files <files@example.com>",
    );
    const sparseCheckoutResult = runSparseCheckoutFlow(
      bitGit,
      memoryApi,
      "/repo-sparse",
      "Sparse <sparse@example.com>",
    );
    const stashDiffCherryPickResult = await runStashDiffCherryPickFlow(
      bitGit,
      memoryApi,
      "/repo-stash",
      "Stash <stash@example.com>",
    );
    const stashPopResult = await runStashPopFlow(
      bitGit,
      memoryApi,
      "/repo-stash-pop",
      "Stash Pop <stash-pop@example.com>",
    );
    const transportHelperResult = await runTransportHelperFlow(bitGit);
    const cloneResult = await runCloneFlow(bitGit);

    return {
      memoryResult,
      customResult,
      signedResult,
      sshSignatureResult,
      directSignedResult,
      mergeResult,
      rebaseResult,
      rebaseOntoResult,
      rebaseControlResult,
      refsTagsResetResult,
      statusAmendSwitchRemoteResult,
      fileOpsResult,
      sparseCheckoutResult,
      stashDiffCherryPickResult,
      stashPopResult,
      transportHelperResult,
      cloneResult,
    };
  } finally {
    bitGit.destroyBackend(memoryApi);
    bitGit.destroyBackend(customBackend);
  }
}

export async function verifyBitGitJsBuild() {
  return verifyBitGitModule(defaultBitGit);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await verifyBitGitJsBuild();
  console.log(JSON.stringify(result, null, 2));
}
