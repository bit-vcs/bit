import assert from "node:assert/strict";
import test from "node:test";

import {
  collectHostedSessions,
  currentBranchName,
  decodeRelaySnapshot,
  encodeRelaySnapshot,
  latestHostedSnapshot,
  readRelayDraftFromSearch,
  relayBaseInfo,
  relayPollUrl,
  relayPublishUrl,
} from "../docs/demo/relay_state.js";
import { readStorageProfileFromSearch } from "../docs/demo/storage.js";

test("shareable search params preserve relay target, editor label, and session", () => {
  const draft = readRelayDraftFromSearch(
    "?relay=relay%2Bhttps%3A%2F%2Frelay.example.com%2Fbase%3Froom%3Dteam-a"
      + "&relay_auth=%20token-1%20"
      + "&editor=%20Host%20"
      + "&session=%20sess-1%20",
  );

  assert.deepEqual(draft, {
    remoteUrl: "relay+https://relay.example.com/base?room=team-a",
    authToken: "token-1",
    editorLabel: "Host",
    selectedSessionId: "sess-1",
  });
});

test("storage profile stays deterministic and browser-safe", () => {
  assert.equal(readStorageProfileFromSearch(""), "default");
  assert.equal(readStorageProfileFromSearch("?profile=Host Tab"), "host-tab");
  assert.equal(readStorageProfileFromSearch("?profile=../Client"), "client");
});

test("relay URL helpers derive base, room, publish, and poll endpoints", () => {
  assert.deepEqual(
    relayBaseInfo("relay+https://relay.example.com/base?room=team-a"),
    {
      baseUrl: "https://relay.example.com/base",
      room: "team-a",
    },
  );
  assert.equal(
    relayPollUrl("relay+https://relay.example.com/base?room=team-a"),
    "https://relay.example.com/base/api/v1/poll?room=team-a&after=0&limit=200",
  );
  assert.equal(
    relayPublishUrl("relay+https://relay.example.com/base?room=team-a", {
      sender: "host-a",
      eventId: "demo-session-1",
    }),
    "https://relay.example.com/base/api/v1/publish?room=team-a&sender=host-a&topic=notify&id=demo-session-1",
  );
});

test("relay snapshot encoding round-trips Uint8Array file payloads", () => {
  const original = {
    dirs: ["/", "/playground"],
    files: [
      { path: "/playground/README.md", data: Uint8Array.from([98, 105, 116, 10]) },
    ],
  };

  const encoded = encodeRelaySnapshot(original);
  const decoded = decodeRelaySnapshot(encoded);

  assert.deepEqual(decoded.dirs, original.dirs);
  assert.equal(decoded.files[0].path, "/playground/README.md");
  assert.deepEqual(Array.from(decoded.files[0].data), [98, 105, 116, 10]);
});

test("session collection prefers the latest snapshot metadata per host", () => {
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
      sender: "host-b",
      payload: {
        kind: "bit.demo.session.v1",
        session_id: "sess-b",
        label: "Host B",
        started_at: 110,
      },
    },
    {
      sender: "host-a",
      payload: {
        kind: "bit.demo.snapshot.v1",
        session_id: "sess-a",
        label: "Host A",
        revision: 2,
        updated_at: 220,
        file_path: "notes/today.md",
        snapshot: encodeRelaySnapshot({ dirs: ["/"], files: [] }),
      },
    },
    {
      sender: "host-b",
      payload: {
        kind: "bit.demo.snapshot.v1",
        session_id: "sess-b",
        label: "Host B",
        revision: 1,
        updated_at: 210,
        file_path: "README.md",
        snapshot: encodeRelaySnapshot({ dirs: ["/"], files: [] }),
      },
    },
  ];

  assert.deepEqual(collectHostedSessions(envelopes), [
    {
      sessionId: "sess-a",
      label: "Host A",
      sender: "host-a",
      startedAt: 100,
      lastRevision: 2,
      lastUpdatedAt: 220,
      filePath: "notes/today.md",
    },
    {
      sessionId: "sess-b",
      label: "Host B",
      sender: "host-b",
      startedAt: 110,
      lastRevision: 1,
      lastUpdatedAt: 210,
      filePath: "README.md",
    },
  ]);
});

test("latestHostedSnapshot returns the newest revision for a connected session", () => {
  const latest = latestHostedSnapshot([
    {
      sender: "host-a",
      payload: {
        kind: "bit.demo.snapshot.v1",
        session_id: "sess-a",
        label: "Host A",
        revision: 1,
        updated_at: 100,
        file_path: "README.md",
        snapshot: encodeRelaySnapshot({
          dirs: ["/"],
          files: [{ path: "/README.md", data: Uint8Array.from([111, 108, 100]) }],
        }),
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
          files: [{ path: "/notes/today.md", data: Uint8Array.from([110, 101, 119]) }],
        }),
      },
    },
  ], "sess-a");

  assert.equal(latest.sessionId, "sess-a");
  assert.equal(latest.revision, 2);
  assert.equal(latest.filePath, "notes/today.md");
  assert.deepEqual(Array.from(latest.snapshot.files[0].data), [110, 101, 119]);
});

test("currentBranchName still prefers the active branch", () => {
  assert.equal(currentBranchName([], "main"), "main");
  assert.equal(
    currentBranchName([
      { name: "main", isCurrent: false },
      { name: "feature/demo", isCurrent: true },
    ]),
    "feature/demo",
  );
});
