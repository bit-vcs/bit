// Regression guard for pushing when the local clone or the remote is shallow.
//
// A repo imported with `depth: 1` (Cloudflare Artifacts does this) advertises a
// tip whose parents it does not have. Packing HEAD's whole history for a push
// used to walk past that boundary into objects nobody has, failing with
// "Missing commit object" even though real git pushes to the same remote fine.
import assert from "node:assert/strict";
import test from "node:test";
import { execFileSync, spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import * as bit from "@mizchi/bit";

const AUTHOR = "bit <bit@example.com>";

function hasGit() {
  try {
    execFileSync("git", ["--version"], { stdio: "ignore" });
    execFileSync("git", ["http-backend", "--help"], { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function git(cwd, ...args) {
  return execFileSync(
    "git",
    [
      "-c", "user.email=dev@example.com",
      "-c", "user.name=dev",
      "-c", "commit.gpgsign=false",
      ...args,
    ],
    { cwd, encoding: "utf8" },
  ).trim();
}

// Serve GIT_PROJECT_ROOT over smart HTTP by piping requests through git's own CGI.
function startHttpBackend(projectRoot) {
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://placeholder");
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      const body = Buffer.concat(chunks);
      const cgi = spawn("git", ["http-backend"], {
        env: {
          ...process.env,
          GIT_PROJECT_ROOT: projectRoot,
          GIT_HTTP_EXPORT_ALL: "1",
          REQUEST_METHOD: req.method,
          PATH_INFO: url.pathname,
          QUERY_STRING: url.search.slice(1),
          CONTENT_TYPE: req.headers["content-type"] ?? "",
          CONTENT_LENGTH: String(body.length),
          REMOTE_USER: "test",
          REMOTE_ADDR: "127.0.0.1",
        },
      });
      const out = [];
      cgi.stdout.on("data", (chunk) => out.push(chunk));
      cgi.on("close", () => {
        const all = Buffer.concat(out);
        const separator = all.indexOf("\r\n\r\n");
        const headers = Object.fromEntries(
          all.subarray(0, separator).toString()
            .split("\r\n")
            .filter((line) => line.includes(":"))
            .map((line) => line.split(/:\s*/)),
        );
        res.writeHead(Number(headers.Status?.split(" ")[0] ?? 200), headers);
        res.end(all.subarray(separator + 4));
      });
      cgi.stdin.end(body);
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

const fetchTransport = {
  async get(url, headers) {
    const response = await fetch(url, { headers });
    return { status: response.status, body: new Uint8Array(await response.arrayBuffer()) };
  },
  async post(url, body, headers) {
    const response = await fetch(url, { method: "POST", headers, body });
    return { status: response.status, body: new Uint8Array(await response.arrayBuffer()) };
  },
};

async function commitAndPush(remoteUrl, cloneOptions, fileName) {
  const backend = bit.createMemoryBackend();
  try {
    await bit.clone(backend, "/repo", remoteUrl, fetchTransport, cloneOptions);
    bit.writeString(backend, `/repo/${fileName}`, "hello\n");
    bit.add(backend, "/repo", ["."]);
    const commitId = bit.commit(
      backend, "/repo", `from bit (${fileName})`, AUTHOR, 1700002000,
    );
    await bit.push(backend, "/repo", remoteUrl, fetchTransport, {
      refname: "refs/heads/main",
      force: false,
    });
    return commitId;
  } finally {
    bit.destroyBackend(backend);
  }
}

test("push succeeds when the clone or the remote is shallow", { skip: !hasGit() && "git with http-backend is unavailable" }, async () => {
  const dir = mkdtempSync(join(tmpdir(), "bit-shallow-push-"));
  let server;
  try {
    // A three-commit origin, plus a depth-1 bare copy of it: the shallow remote
    // holds only c3, so c3's parents exist nowhere the client can reach.
    const origin = join(dir, "origin.git");
    const work = join(dir, "work");
    git(dir, "init", "-q", "--bare", origin);
    git(origin, "config", "http.receivepack", "true");
    git(dir, "clone", "-q", origin, work);
    for (const n of [1, 2, 3]) {
      writeFileSync(join(work, `f${n}.txt`), `${n}\n`);
      git(work, "add", ".");
      git(work, "commit", "-q", "-m", `c${n}`);
    }
    git(work, "push", "-q", "origin", "HEAD:refs/heads/main");
    git(origin, "symbolic-ref", "HEAD", "refs/heads/main");

    const shallow = join(dir, "shallow.git");
    git(dir, "clone", "-q", "--bare", "--depth", "1", `file://${origin}`, shallow);
    git(shallow, "config", "http.receivepack", "true");
    git(shallow, "symbolic-ref", "HEAD", "refs/heads/main");
    assert.equal(git(shallow, "rev-list", "--count", "main"), "1");

    server = await startHttpBackend(dir);
    const base = `http://127.0.0.1:${server.address().port}`;

    for (const [label, repo, depth] of [
      ["full remote, full clone", origin, undefined],
      ["full remote, depth 1", origin, 1],
      ["shallow remote, full clone", shallow, undefined],
      ["shallow remote, depth 1", shallow, 1],
    ]) {
      const remoteUrl = `${base}/${repo === origin ? "origin" : "shallow"}.git`;
      const fileName = `${label.replace(/[^a-z0-9]+/gi, "-")}.txt`;
      const commitId = await commitAndPush(remoteUrl, depth ? { depth } : {}, fileName);
      assert.equal(commitId.length, 40, label);
      // The receiver accepted the pack and moved its branch to our commit.
      assert.equal(git(repo, "rev-parse", "main"), commitId, label);
      assert.equal(git(repo, "cat-file", "-e", `${commitId}^{tree}`), "", label);
    }
  } finally {
    if (server) server.close();
    rmSync(dir, { recursive: true, force: true });
  }
});
