import {
  DEMO_SESSION_KIND,
  DEMO_SNAPSHOT_KIND,
  collectHostedSessions,
  encodeRelaySnapshot,
  latestHostedSnapshot,
  relayPollUrl,
  relayPublishUrl,
  trimOptionalText,
} from "./relay_state.js";

const jsonHeaders = (authToken) => {
  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
  };
  if (authToken) {
    headers.Authorization = `Bearer ${authToken}`;
  }
  return headers;
};

const readJson = async (response) => {
  const payload = await response.json().catch(async () => {
    const text = await response.text();
    throw new Error(text || `HTTP ${response.status}`);
  });
  if (!response.ok || payload?.ok === false) {
    throw new Error(payload?.error ?? `HTTP ${response.status}`);
  }
  return payload;
};

export const publishHostedSession = async (
  fetchImpl,
  remoteUrl,
  authToken,
  session,
) => {
  const sessionId = trimOptionalText(session?.sessionId);
  const label = trimOptionalText(session?.label);
  const sender = trimOptionalText(session?.sender) ?? label;
  if (!sessionId || !label || !sender) {
    throw new Error("Hosted session requires sessionId, label, and sender.");
  }

  const response = await fetchImpl(
    relayPublishUrl(remoteUrl, {
      sender,
      eventId: `demo-session-${sessionId}`,
    }),
    {
      method: "POST",
      headers: jsonHeaders(authToken),
      body: JSON.stringify({
        payload: {
          kind: DEMO_SESSION_KIND,
          session_id: sessionId,
          label,
          started_at: session.startedAt ?? Date.now(),
        },
      }),
    },
  );
  await readJson(response);
};

export const publishHostedSnapshot = async (
  fetchImpl,
  remoteUrl,
  authToken,
  session,
  snapshot,
  metadata = {},
) => {
  const sessionId = trimOptionalText(session?.sessionId);
  const label = trimOptionalText(session?.label);
  const sender = trimOptionalText(session?.sender) ?? label;
  if (!sessionId || !label || !sender) {
    throw new Error("Hosted session requires sessionId, label, and sender.");
  }

  const revision = Math.max(1, Math.trunc(Number(metadata.revision) || 0));
  const response = await fetchImpl(
    relayPublishUrl(remoteUrl, {
      sender,
      eventId: `demo-snapshot-${sessionId}-${revision}`,
    }),
    {
      method: "POST",
      headers: jsonHeaders(authToken),
      body: JSON.stringify({
        payload: {
          kind: DEMO_SNAPSHOT_KIND,
          session_id: sessionId,
          label,
          revision,
          updated_at: metadata.updatedAt ?? Date.now(),
          file_path: metadata.filePath ?? "",
          snapshot: encodeRelaySnapshot(snapshot),
        },
      }),
    },
  );
  await readJson(response);
};

export const pollRelayEnvelopes = async (fetchImpl, remoteUrl, authToken) => {
  const response = await fetchImpl(
    relayPollUrl(remoteUrl),
    {
      headers: authToken ? { Accept: "application/json", Authorization: `Bearer ${authToken}` } : { Accept: "application/json" },
    },
  );
  const payload = await readJson(response);
  return Array.isArray(payload.envelopes) ? payload.envelopes : [];
};

export const listHostedEditors = async (fetchImpl, remoteUrl, authToken) => (
  collectHostedSessions(await pollRelayEnvelopes(fetchImpl, remoteUrl, authToken))
);

export const loadHostedEditorSnapshot = async (
  fetchImpl,
  remoteUrl,
  authToken,
  sessionId,
) => {
  const envelopes = await pollRelayEnvelopes(fetchImpl, remoteUrl, authToken);
  return latestHostedSnapshot(envelopes, sessionId);
};
