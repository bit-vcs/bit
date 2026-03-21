const trimTrailingSlash = (value) => (
  value.length > 1 && value.endsWith("/") ? value.slice(0, -1) : value
);

export const DEFAULT_DEMO_RELAY_ROOM = "playground";
export const DEMO_SESSION_KIND = "bit.demo.session.v1";
export const DEMO_SNAPSHOT_KIND = "bit.demo.snapshot.v1";

export const trimOptionalText = (value) => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
};

const relayToHttpUrl = (remoteUrl) => {
  const normalized = trimOptionalText(remoteUrl);
  if (!normalized) return null;
  if (normalized.startsWith("relay+http://") || normalized.startsWith("relay+https://")) {
    return normalized.slice(6);
  }
  if (normalized.startsWith("relay://")) {
    return `http://${normalized.slice(8)}`;
  }
  if (normalized.startsWith("http://") || normalized.startsWith("https://")) {
    return normalized;
  }
  return null;
};

const encodeBase64 = (bytesLike) => {
  const bytes = bytesLike instanceof Uint8Array ? bytesLike : Uint8Array.from(bytesLike ?? []);
  if (typeof Buffer !== "undefined") {
    return Buffer.from(bytes).toString("base64");
  }
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
};

const decodeBase64 = (value) => {
  if (typeof value !== "string" || value.length === 0) {
    return new Uint8Array();
  }
  if (typeof Buffer !== "undefined") {
    return Uint8Array.from(Buffer.from(value, "base64"));
  }
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
};

export const readRelayDraftFromSearch = (search = "") => {
  const params = new URLSearchParams(String(search).replace(/^\?/, ""));
  return {
    remoteUrl: trimOptionalText(params.get("relay")) ?? "",
    authToken: trimOptionalText(params.get("relay_auth")) ?? "",
    editorLabel: trimOptionalText(params.get("editor")) ?? "",
    selectedSessionId: trimOptionalText(params.get("session")) ?? "",
  };
};

export const relayBaseInfo = (remoteUrl) => {
  const httpUrl = relayToHttpUrl(remoteUrl);
  if (!httpUrl) {
    throw new Error("Relay URL must use relay+https://, relay+http://, relay://, or http(s)://");
  }
  const url = new URL(httpUrl);
  const room = trimOptionalText(url.searchParams.get("room")) ?? DEFAULT_DEMO_RELAY_ROOM;
  url.search = "";
  return {
    baseUrl: trimTrailingSlash(url.toString()),
    room,
  };
};

export const relayPollUrl = (remoteUrl, after = 0, limit = 200) => {
  const relay = relayBaseInfo(remoteUrl);
  const url = new URL(`${relay.baseUrl}/api/v1/poll`);
  url.searchParams.set("room", relay.room);
  url.searchParams.set("after", String(Math.max(0, Math.trunc(after))));
  url.searchParams.set("limit", String(Math.max(1, Math.trunc(limit))));
  return url.toString();
};

export const relayPublishUrl = (remoteUrl, { sender, eventId, topic = "notify" }) => {
  const relay = relayBaseInfo(remoteUrl);
  const url = new URL(`${relay.baseUrl}/api/v1/publish`);
  url.searchParams.set("room", relay.room);
  url.searchParams.set("sender", sender);
  url.searchParams.set("topic", topic);
  url.searchParams.set("id", eventId);
  return url.toString();
};

export const currentBranchName = (branches, fallback = "main") => (
  Array.isArray(branches) && branches.find((branch) => branch?.isCurrent)?.name
) ?? fallback;

export const encodeRelaySnapshot = (snapshot) => ({
  dirs: Array.from(snapshot?.dirs ?? ["/"]),
  files: Array.from(snapshot?.files ?? []).map((file) => ({
    path: String(file.path),
    dataBase64: encodeBase64(file.data ?? new Uint8Array()),
  })),
});

export const decodeRelaySnapshot = (encodedSnapshot) => ({
  dirs: Array.from(encodedSnapshot?.dirs ?? ["/"]),
  files: Array.from(encodedSnapshot?.files ?? []).map((file) => ({
    path: String(file.path),
    data: decodeBase64(file.dataBase64 ?? ""),
  })),
});

const toTimestamp = (value) => {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : 0;
};

export const collectHostedSessions = (envelopes) => {
  const sessions = new Map();

  for (const envelope of Array.isArray(envelopes) ? envelopes : []) {
    const payload = envelope?.payload;
    if (!payload || typeof payload !== "object") continue;

    if (payload.kind === DEMO_SESSION_KIND) {
      const sessionId = trimOptionalText(payload.session_id);
      if (!sessionId) continue;
      const existing = sessions.get(sessionId) ?? {
        sessionId,
        label: sessionId,
        sender: trimOptionalText(envelope.sender) ?? "editor",
        startedAt: 0,
        lastRevision: 0,
        lastUpdatedAt: 0,
        filePath: null,
      };
      sessions.set(sessionId, {
        ...existing,
        label: trimOptionalText(payload.label) ?? existing.label,
        sender: trimOptionalText(envelope.sender) ?? existing.sender,
        startedAt: Math.max(existing.startedAt, toTimestamp(payload.started_at)),
      });
      continue;
    }

    if (payload.kind === DEMO_SNAPSHOT_KIND) {
      const sessionId = trimOptionalText(payload.session_id);
      if (!sessionId) continue;
      const existing = sessions.get(sessionId) ?? {
        sessionId,
        label: trimOptionalText(payload.label) ?? sessionId,
        sender: trimOptionalText(envelope.sender) ?? "editor",
        startedAt: 0,
        lastRevision: 0,
        lastUpdatedAt: 0,
        filePath: null,
      };
      const revision = Math.max(existing.lastRevision, Math.trunc(Number(payload.revision) || 0));
      const updatedAt = Math.max(existing.lastUpdatedAt, toTimestamp(payload.updated_at));
      sessions.set(sessionId, {
        ...existing,
        label: trimOptionalText(payload.label) ?? existing.label,
        sender: trimOptionalText(envelope.sender) ?? existing.sender,
        lastRevision: revision,
        lastUpdatedAt: updatedAt,
        filePath: trimOptionalText(payload.file_path) ?? existing.filePath,
      });
    }
  }

  return Array.from(sessions.values()).sort((left, right) => (
    right.lastUpdatedAt - left.lastUpdatedAt
    || right.startedAt - left.startedAt
    || left.label.localeCompare(right.label)
  ));
};

export const latestHostedSnapshot = (envelopes, sessionId) => {
  let latest = null;

  for (const envelope of Array.isArray(envelopes) ? envelopes : []) {
    const payload = envelope?.payload;
    if (!payload || payload.kind !== DEMO_SNAPSHOT_KIND || payload.session_id !== sessionId) {
      continue;
    }
    const candidate = {
      sessionId,
      label: trimOptionalText(payload.label) ?? sessionId,
      sender: trimOptionalText(envelope.sender) ?? "editor",
      revision: Math.trunc(Number(payload.revision) || 0),
      updatedAt: toTimestamp(payload.updated_at),
      filePath: trimOptionalText(payload.file_path),
      snapshot: decodeRelaySnapshot(payload.snapshot),
    };
    if (!latest || candidate.revision > latest.revision || candidate.updatedAt > latest.updatedAt) {
      latest = candidate;
    }
  }

  return latest;
};
