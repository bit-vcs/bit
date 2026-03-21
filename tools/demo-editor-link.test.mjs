import assert from "node:assert/strict";
import test from "node:test";

import {
  listHostedEditors,
  loadHostedEditorSnapshot,
  publishHostedSession,
  publishHostedSnapshot,
} from "../docs/demo/editor_link.js";
import { encodeRelaySnapshot } from "../docs/demo/relay_state.js";

const jsonResponse = (payload) => ({
  ok: true,
  status: 200,
  async json() {
    return payload;
  },
  async text() {
    return JSON.stringify(payload);
  },
});

test("publishHostedSession posts the expected announcement envelope", async () => {
  const calls = [];
  await publishHostedSession(
    async (url, init) => {
      calls.push({ url, init });
      return jsonResponse({ ok: true, accepted: true, cursor: 1 });
    },
    "relay+https://relay.example.com/base?room=team-a",
    "token-1",
    {
      sessionId: "sess-a",
      label: "Host A",
      sender: "host-a",
      startedAt: 100,
    },
  );

  assert.equal(
    calls[0].url,
    "https://relay.example.com/base/api/v1/publish?room=team-a&sender=host-a&topic=notify&id=demo-session-sess-a",
  );
  assert.equal(calls[0].init.method, "POST");
  assert.equal(calls[0].init.headers.Authorization, "Bearer token-1");
  assert.deepEqual(JSON.parse(calls[0].init.body), {
    payload: {
      kind: "bit.demo.session.v1",
      session_id: "sess-a",
      label: "Host A",
      started_at: 100,
    },
  });
});

test("publishHostedSnapshot serializes snapshot payloads with monotonically increasing revision", async () => {
  const calls = [];
  await publishHostedSnapshot(
    async (url, init) => {
      calls.push({ url, init });
      return jsonResponse({ ok: true, accepted: true, cursor: 2 });
    },
    "relay+https://relay.example.com/base?room=team-a",
    null,
    {
      sessionId: "sess-a",
      label: "Host A",
      sender: "host-a",
    },
    {
      dirs: ["/"],
      files: [{ path: "/README.md", data: Uint8Array.from([98, 105, 116]) }],
    },
    {
      revision: 3,
      updatedAt: 200,
      filePath: "README.md",
    },
  );

  const payload = JSON.parse(calls[0].init.body);
  assert.equal(
    calls[0].url,
    "https://relay.example.com/base/api/v1/publish?room=team-a&sender=host-a&topic=notify&id=demo-snapshot-sess-a-3",
  );
  assert.equal(payload.payload.kind, "bit.demo.snapshot.v1");
  assert.equal(payload.payload.revision, 3);
  assert.equal(payload.payload.file_path, "README.md");
  assert.deepEqual(payload.payload.snapshot, encodeRelaySnapshot({
    dirs: ["/"],
    files: [{ path: "/README.md", data: Uint8Array.from([98, 105, 116]) }],
  }));
});

test("listHostedEditors and loadHostedEditorSnapshot reuse poll envelopes", async () => {
  const envelopes = [
    {
      sender: "host-a",
      payload: {
        kind: "bit.demo.session.v1",
        session_id: "sess-a",
        label: "Host A",
        started_at: 100,
      },
    },
    {
      sender: "host-a",
      payload: {
        kind: "bit.demo.snapshot.v1",
        session_id: "sess-a",
        label: "Host A",
        revision: 2,
        updated_at: 200,
        file_path: "notes/today.md",
        snapshot: encodeRelaySnapshot({
          dirs: ["/"],
          files: [{ path: "/notes/today.md", data: Uint8Array.from([111, 107]) }],
        }),
      },
    },
  ];

  const fetchImpl = async (url) => {
    assert.equal(
      url,
      "https://relay.example.com/base/api/v1/poll?room=team-a&after=0&limit=200",
    );
    return jsonResponse({ ok: true, envelopes });
  };

  assert.deepEqual(
    await listHostedEditors(fetchImpl, "relay+https://relay.example.com/base?room=team-a", null),
    [
      {
        sessionId: "sess-a",
        label: "Host A",
        sender: "host-a",
        startedAt: 100,
        lastRevision: 2,
        lastUpdatedAt: 200,
        filePath: "notes/today.md",
      },
    ],
  );

  const snapshot = await loadHostedEditorSnapshot(
    fetchImpl,
    "relay+https://relay.example.com/base?room=team-a",
    null,
    "sess-a",
  );
  assert.equal(snapshot.revision, 2);
  assert.deepEqual(Array.from(snapshot.snapshot.files[0].data), [111, 107]);
});
