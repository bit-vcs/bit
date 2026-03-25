import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const defaultBitGit = await import(new URL("./bit-git.mjs", import.meta.url));

function jsonBody(value) {
  return new TextEncoder().encode(JSON.stringify(value));
}

async function verifyRelayHelpers(bitGit) {
  const calls = [];
  const relayUrl = "relay+https://relay.example.com/base?room=team-a&room_token=token-1";
  const transport = {
    async get(url, headers) {
      calls.push({ method: "GET", url, headers });
      if (url.startsWith("https://relay.example.com/base/api/v1/poll?")) {
        return {
          status: 200,
          body: jsonBody({
            ok: true,
            next_cursor: 4,
            envelopes: [
              {
                sender: "node-b",
                payload: {
                  kind: "bit.clone.announce.v1",
                  clone_url: "https://peer-b.example/repo.git",
                  repo: "repo-b",
                },
              },
              {
                sender: "node-a",
                payload: {
                  kind: "bit.clone.announce.v1",
                  clone_url: "https://peer-a-old.example/repo.git",
                },
              },
              {
                sender: "node-a",
                payload: {
                  kind: "bit.clone.announce.v1",
                  clone_url: "https://peer-a.example/repo.git",
                  repo: " repo-a ",
                },
              },
              {
                sender: "node-z",
                payload: { kind: "hub.record", record: "ignored" },
              },
            ],
          }),
        };
      }
      throw new Error(`unexpected relay GET ${url}`);
    },
    async post(url) {
      throw new Error(`unexpected relay POST ${url}`);
    },
  };

  const peers = await bitGit.relayListClonePeers(relayUrl, transport, {
    authToken: "auth-1",
  });
  assert.deepEqual(peers, [
    {
      sender: "node-a",
      cloneUrl: "https://peer-a.example/repo.git",
      repo: "repo-a",
    },
    {
      sender: "node-b",
      cloneUrl: "https://peer-b.example/repo.git",
      repo: "repo-b",
    },
  ]);
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].url,
    "https://relay.example.com/base/api/v1/poll?room=team-a&after=0&limit=200&room_token=token-1",
  );
  assert.equal(calls[0].headers.Authorization, "Bearer auth-1");

  const resolvedByRepo = await bitGit.relayResolveRemote(relayUrl, transport, {
    preferredRepo: "repo-b",
  });
  assert.deepEqual(resolvedByRepo, {
    via: "peer",
    url: "https://peer-b.example/repo.git",
    sender: "node-b",
    repo: "repo-b",
    sessionId: null,
  });

  const resolvedSession = await bitGit.relayResolveRemote(
    "relay+https://relay.example.com/base/AbCd1234",
    transport,
  );
  assert.deepEqual(resolvedSession, {
    via: "session",
    url: "https://relay.example.com/base/git/AbCd1234",
    sender: null,
    repo: null,
    sessionId: "AbCd1234",
  });
}

async function verifyFetchAndPushResolveRelay(bitGit) {
  const calls = [];
  const relayUrl = "relay+https://relay.example.com/base?room=team-a";
  const transport = {
    async get(url, headers) {
      calls.push({ method: "GET", url, headers });
      if (url.startsWith("https://relay.example.com/base/api/v1/poll?")) {
        return {
          status: 200,
          body: jsonBody({
            ok: true,
            next_cursor: 1,
            envelopes: [
              {
                sender: "node-b",
                payload: {
                  kind: "bit.clone.announce.v1",
                  clone_url: "https://peer-b.example/repo.git",
                  repo: "repo-b",
                },
              },
            ],
          }),
        };
      }
      if (url.startsWith("https://peer-b.example/repo/info/refs?service=git-upload-pack")) {
        return { status: 404, body: new Uint8Array() };
      }
      if (url.startsWith("https://peer-b.example/repo/info/refs?service=git-receive-pack")) {
        return { status: 404, body: new Uint8Array() };
      }
      throw new Error(`unexpected GET ${url}`);
    },
    async post(url) {
      calls.push({ method: "POST", url, headers: {} });
      throw new Error(`unexpected POST ${url}`);
    },
  };

  const backend = bitGit.createMemoryBackend();
  bitGit.init(backend, "/repo");
  bitGit.writeString(backend, "/repo/file.txt", "hello\n");
  bitGit.add(backend, "/repo", ["file.txt"]);
  bitGit.commit(backend, "/repo", "initial", "Relay <relay@example.com>", 1700000300);

  await assert.rejects(
    bitGit.fetch(backend, "/repo", relayUrl, transport, {
      refspec: "main",
      preferredSender: "node-b",
    }),
  );
  assert.equal(calls[0].url, "https://relay.example.com/base/api/v1/poll?room=team-a&after=0&limit=200");
  assert.equal(
    calls[1].url,
    "https://peer-b.example/repo/info/refs?service=git-upload-pack",
  );

  calls.length = 0;
  await assert.rejects(
    bitGit.push(backend, "/repo", relayUrl, transport, {
      preferredRepo: "repo-b",
    }),
  );
  assert.equal(calls[0].url, "https://relay.example.com/base/api/v1/poll?room=team-a&after=0&limit=200");
  assert.equal(
    calls[1].url,
    "https://peer-b.example/repo/info/refs?service=git-receive-pack",
  );
}

export async function verifyRelayModule(bitGit = defaultBitGit) {
  await verifyRelayHelpers(bitGit);
  await verifyFetchAndPushResolveRelay(bitGit);
  return "ok";
}

export async function verifyRelayJsBuild() {
  return verifyRelayModule(defaultBitGit);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await verifyRelayJsBuild();
  console.log(result);
}
