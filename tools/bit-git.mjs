import {
  add as rawAdd,
  branchCreate as rawBranchCreate,
  branchDelete as rawBranchDelete,
  branchList as rawBranchList,
  branchRename as rawBranchRename,
  buildCommitPayload as rawBuildCommitPayload,
  cherryPick as rawCherryPick,
  checkout as rawCheckout,
  checkoutB as rawCheckoutB,
  commit as rawCommit,
  commitSigned as rawCommitSigned,
  diffIndex as rawDiffIndex,
  diffIndexStat as rawDiffIndexStat,
  diffWorktree as rawDiffWorktree,
  diffWorktreeStat as rawDiffWorktreeStat,
  destroyHost as rawDestroyHost,
  fetch as rawFetch,
  getRemoteUrl as rawGetRemoteUrl,
  hostReadString as rawHostReadString,
  hostWriteString as rawHostWriteString,
  init as rawInit,
  listRemotes as rawListRemotes,
  log as rawLog,
  merge as rawMerge,
  mv as rawMv,
  push as rawPush,
  rebaseAbort as rawRebaseAbort,
  rebaseContinue as rawRebaseContinue,
  rebaseSkip as rawRebaseSkip,
  rebaseStart as rawRebaseStart,
  rebaseStartWithOnto as rawRebaseStartWithOnto,
  reset as rawReset,
  restore as rawRestore,
  revParse as rawRevParse,
  rm as rawRm,
  showRef as rawShowRef,
  stashApply as rawStashApply,
  stashDrop as rawStashDrop,
  stashList as rawStashList,
  stashPush as rawStashPush,
  status as rawStatus,
  statusPorcelain as rawStatusPorcelain,
  tagCreateAnnotated as rawTagCreateAnnotated,
  tagCreateLightweight as rawTagCreateLightweight,
  tagDelete as rawTagDelete,
  tagList as rawTagList,
} from "../_build/js/release/build/lib/lib.js";

const ensureState = () => (
  globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() }
);

const ensureTransportState = () => (
  globalThis.__bitGitJsTransportState ??= { nextTransportId: 1, transports: new Map() }
);

const backendHostIds = new WeakMap();
const transportIds = new WeakMap();
const fetchTransportCache = new WeakMap();

const isMoonBitResult = (value) => (
  !!value &&
  typeof value === "object" &&
  "$tag" in value
);

const unwrap = (label, result) => {
  let current = result;
  while (isMoonBitResult(current)) {
    if (current.$tag === 1) {
      current = current._0;
      continue;
    }
    throw new Error(`${label}: ${String(current._0 ?? "bit-git js error")}`);
  }
  return current;
};

const unwrapAsync = async (label, resultPromise) => unwrap(label, await resultPromise);

const isBackendObject = (value) => (
  !!value &&
  typeof value === "object" &&
  typeof value.readFile === "function" &&
  typeof value.readdir === "function" &&
  typeof value.isDir === "function" &&
  typeof value.isFile === "function"
);

const isTransportObject = (value) => (
  !!value &&
  typeof value === "object" &&
  typeof value.get === "function" &&
  typeof value.post === "function"
);

const registerBackend = (backend) => {
  const cached = backendHostIds.get(backend);
  if (cached !== undefined) {
    return cached;
  }
  const state = ensureState();
  const hostId = state.nextHostId++;
  state.hosts.set(hostId, backend);
  backendHostIds.set(backend, hostId);
  return hostId;
};

const toHostId = (backend) => {
  if (isBackendObject(backend)) {
    return registerBackend(backend);
  }
  throw new TypeError("expected BitGit backend");
};

export const createFetchTransport = (fetchImpl) => {
  if (typeof fetchImpl !== "function") {
    throw new TypeError("expected fetch implementation");
  }
  return {
    async get(url, headers) {
      const response = await fetchImpl(url, { method: "GET", headers });
      return {
        status: response.status,
        body: new Uint8Array(await response.arrayBuffer()),
      };
    },
    async post(url, body, headers) {
      const response = await fetchImpl(url, { method: "POST", headers, body });
      return {
        status: response.status,
        body: new Uint8Array(await response.arrayBuffer()),
      };
    },
  };
};

const normalizeTransport = (transportOrFetch) => {
  if (isTransportObject(transportOrFetch)) {
    return transportOrFetch;
  }
  if (typeof transportOrFetch === "function") {
    const cached = fetchTransportCache.get(transportOrFetch);
    if (cached) {
      return cached;
    }
    const transport = createFetchTransport(transportOrFetch);
    fetchTransportCache.set(transportOrFetch, transport);
    return transport;
  }
  throw new TypeError("expected BitGit transport or fetch implementation");
};

const toTransportId = (transportOrFetch) => {
  const transport = normalizeTransport(transportOrFetch);
  const cached = transportIds.get(transport);
  if (cached !== undefined) {
    return cached;
  }
  const state = ensureTransportState();
  const transportId = state.nextTransportId++;
  state.transports.set(transportId, transport);
  transportIds.set(transport, transportId);
  return transportId;
};

const toUint8Array = (value) => {
  if (value == null) return new Uint8Array();
  if (value instanceof Uint8Array) return value;
  if (typeof ArrayBuffer !== "undefined" && value instanceof ArrayBuffer) {
    return new Uint8Array(value);
  }
  if (typeof ArrayBuffer !== "undefined" && ArrayBuffer.isView(value)) {
    return new Uint8Array(value.buffer, value.byteOffset, value.byteLength);
  }
  if (typeof value === "string") {
    return new TextEncoder().encode(value);
  }
  return Uint8Array.from(value);
};

const relayUsesSignaling = (remoteUrl) => (
  typeof remoteUrl === "string" &&
  (
    remoteUrl.startsWith("relay+http://") ||
    remoteUrl.startsWith("relay+https://") ||
    remoteUrl.startsWith("relay://")
  )
);

const trimTrailingSlash = (value) => (
  value.length > 1 && value.endsWith("/") ? value.slice(0, -1) : value
);

const relayToHttpUrl = (remoteUrl) => {
  if (typeof remoteUrl !== "string") {
    throw new TypeError("expected remote URL string");
  }
  if (remoteUrl.startsWith("relay+http://") || remoteUrl.startsWith("relay+https://")) {
    return remoteUrl.slice(6);
  }
  if (remoteUrl.startsWith("relay://")) {
    return `http://${remoteUrl.slice(8)}`;
  }
  if (remoteUrl.startsWith("http://") || remoteUrl.startsWith("https://")) {
    return remoteUrl;
  }
  throw new TypeError("relay url must be relay+http(s)://, relay://, or http(s)://");
};

const relayDetectSession = (remoteUrl) => {
  if (!relayUsesSignaling(remoteUrl)) {
    return null;
  }
  const normalized = trimTrailingSlash(relayToHttpUrl(remoteUrl));
  const slashIndex = normalized.lastIndexOf("/");
  if (slashIndex < 0) return null;
  const sessionId = normalized.slice(slashIndex + 1);
  if (!/^[A-Za-z0-9]{6,16}$/.test(sessionId)) {
    return null;
  }
  return {
    baseUrl: normalized.slice(0, slashIndex),
    sessionId,
    url: `${normalized.slice(0, slashIndex)}/git/${sessionId}`,
  };
};

const relayResolveControlEndpoint = (remoteUrl) => {
  const raw = trimTrailingSlash(relayToHttpUrl(remoteUrl));
  const url = new URL(raw);
  const room = (url.searchParams.get("room") ?? "main").trim() || "main";
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(room)) {
    throw new Error(`invalid relay room: ${room}`);
  }
  const roomToken = (url.searchParams.get("room_token") ?? "").trim() || null;
  url.search = "";
  return {
    baseUrl: trimTrailingSlash(url.toString()),
    room,
    roomToken,
  };
};

const relayPollUrl = ({ baseUrl, room, roomToken }) => {
  const url = new URL(`${baseUrl}/api/v1/poll`);
  url.searchParams.set("room", room);
  url.searchParams.set("after", "0");
  url.searchParams.set("limit", "200");
  if (roomToken) {
    url.searchParams.set("room_token", roomToken);
  }
  return url.toString();
};

const relayAuthHeaders = (authToken) => (
  authToken ? { Accept: "application/json", Authorization: `Bearer ${authToken}` } : { Accept: "application/json" }
);

const relayDecodeJsonBody = (body) => (
  JSON.parse(new TextDecoder().decode(toUint8Array(body)))
);

const normalizeOptionalText = (value) => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
};

export const relayListClonePeers = async (remoteUrl, transportOrFetch, options = {}) => {
  const transport = normalizeTransport(transportOrFetch);
  const endpoint = relayResolveControlEndpoint(remoteUrl);
  const response = await transport.get(
    relayPollUrl(endpoint),
    relayAuthHeaders(options.authToken ?? null),
  );
  if (Math.trunc(response?.status ?? response?.code ?? 0) !== 200) {
    throw new Error(`relay poll failed: HTTP ${Math.trunc(response?.status ?? response?.code ?? 0)}`);
  }
  const payload = relayDecodeJsonBody(response?.body);
  const peersBySender = new Map();
  for (const envelope of Array.isArray(payload?.envelopes) ? payload.envelopes : []) {
    const sender = normalizeOptionalText(envelope?.sender);
    const kind = normalizeOptionalText(envelope?.payload?.kind);
    const cloneUrl = normalizeOptionalText(envelope?.payload?.clone_url);
    if (!sender || kind !== "bit.clone.announce.v1" || !cloneUrl) {
      continue;
    }
    peersBySender.set(sender, {
      sender,
      cloneUrl,
      repo: normalizeOptionalText(envelope?.payload?.repo),
    });
  }
  return Array.from(peersBySender.values()).sort((a, b) => a.sender.localeCompare(b.sender));
};

const selectRelayPeer = (peers, options = {}) => {
  if (options.preferredSender) {
    const bySender = peers.find((peer) => peer.sender === options.preferredSender);
    if (bySender) return bySender;
  }
  if (options.preferredRepo) {
    const byRepo = peers.find((peer) => peer.repo === options.preferredRepo);
    if (byRepo) return byRepo;
  }
  return peers[0] ?? null;
};

export const relayResolveRemote = async (remoteUrl, transportOrFetch, options = {}) => {
  const session = relayDetectSession(remoteUrl);
  if (session) {
    return {
      via: "session",
      url: session.url,
      sender: null,
      repo: null,
      sessionId: session.sessionId,
    };
  }
  const peers = await relayListClonePeers(remoteUrl, transportOrFetch, {
    authToken: options.authToken ?? null,
  });
  const selected = selectRelayPeer(peers, options);
  if (!selected) {
    throw new Error(`No relay peers announced via relay: ${remoteUrl}`);
  }
  return {
    via: "peer",
    url: selected.cloneUrl,
    sender: selected.sender,
    repo: selected.repo,
    sessionId: null,
  };
};

const toStatus = (value) => ({
  stagedAdded: Array.from(value.staged_added),
  stagedModified: Array.from(value.staged_modified),
  stagedDeleted: Array.from(value.staged_deleted),
  unstagedModified: Array.from(value.unstaged_modified),
  unstagedDeleted: Array.from(value.unstaged_deleted),
  untracked: Array.from(value.untracked),
});

const toBranchInfo = (value) => ({
  name: value.name,
  commitId: value.commit_id,
  isCurrent: Boolean(value.is_current),
});

const toLogEntry = (value) => ({
  id: value.id,
  author: value.author,
  message: value.message,
  timestamp: value.timestamp,
});

const toRefInfo = (value) => ({
  name: value.name,
  id: value.id,
});

const toStashEntry = (value) => ({
  id: value.id,
  message: value.message,
});

const toMaybeString = (value) => (
  typeof value === "string" && value.length > 0 ? value : null
);

const mergeStatusMap = {
  already_up_to_date: "alreadyUpToDate",
  fast_forward: "fastForward",
  merged: "merged",
  conflicted: "conflicted",
};

const rebaseStatusMap = {
  complete: "complete",
  conflict: "conflict",
  nothing_to_rebase: "nothingToRebase",
};

const cherryPickStatusMap = {
  success: "success",
  conflict: "conflict",
};

const toMergeResult = (value) => ({
  status: mergeStatusMap[value.status] ?? value.status,
  commitId: toMaybeString(value.commit_id),
  conflicts: Array.from(value.conflicts),
});

const toRebaseResult = (value) => ({
  status: rebaseStatusMap[value.status] ?? value.status,
  commitId: toMaybeString(value.commit_id),
  conflicts: Array.from(value.conflicts),
});

const toCherryPickResult = (value) => ({
  status: cherryPickStatusMap[value.status] ?? value.status,
  commitId: toMaybeString(value.commit_id),
  conflicts: Array.from(value.conflicts),
});

const toFetchResult = (value) => ({
  status: value.status,
  commitId: toMaybeString(value.commit_id),
  refname: toMaybeString(value.refname),
  remoteRef: toMaybeString(value.remote_ref),
});

const createMemoryBackend = () => {
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
};

export const createMemoryHost = () => createMemoryBackend();

export const destroyHost = (backend) => {
  if (!isBackendObject(backend)) {
    throw new TypeError("expected BitGit backend");
  }
  const hostId = backendHostIds.get(backend);
  if (hostId === undefined) {
    return;
  }
  backendHostIds.delete(backend);
  rawDestroyHost(hostId);
};

export const writeString = (backend, path, content) => {
  unwrap("writeString", rawHostWriteString(toHostId(backend), path, content));
};

export const readString = (backend, path) => (
  unwrap("readString", rawHostReadString(toHostId(backend), path))
);

export const init = (backend, root, defaultBranch = "main") => {
  unwrap("init", rawInit(toHostId(backend), root, defaultBranch));
};

export const add = (backend, root, paths) => {
  unwrap("add", rawAdd(toHostId(backend), root, Array.from(paths)));
};

export const status = (backend, root) => (
  toStatus(unwrap("status", rawStatus(toHostId(backend), root)))
);

export const statusPorcelain = (backend, root) => (
  Array.from(unwrap("statusPorcelain", rawStatusPorcelain(toHostId(backend), root)))
);

export const commit = (
  backend,
  root,
  message,
  author,
  timestampSec = Math.floor(Date.now() / 1000),
) => (
  unwrap("commit", rawCommit(toHostId(backend), root, message, author, Math.trunc(timestampSec)))
);

export const buildCommitPayload = (
  backend,
  root,
  message,
  author,
  timestampSec = Math.floor(Date.now() / 1000),
) => (
  unwrap(
    "buildCommitPayload",
    rawBuildCommitPayload(toHostId(backend), root, message, author, Math.trunc(timestampSec)),
  )
);

export const commitSigned = (
  backend,
  root,
  message,
  author,
  signature,
  timestampSec = Math.floor(Date.now() / 1000),
) => (
  unwrap(
    "commitSigned",
    rawCommitSigned(
      toHostId(backend),
      root,
      message,
      author,
      Math.trunc(timestampSec),
      signature,
    ),
  )
);

export const commitWithSigner = async (
  backend,
  root,
  message,
  author,
  signer,
  timestampSec = Math.floor(Date.now() / 1000),
) => {
  const payload = buildCommitPayload(backend, root, message, author, timestampSec);
  const signature = await signer(payload);
  if (typeof signature !== "string" || signature.length === 0) {
    throw new TypeError("signer must return a non-empty signature string");
  }
  return commitSigned(backend, root, message, author, signature, timestampSec);
};

export const log = (backend, root, maxCount = 32) => (
  Array.from(unwrap("log", rawLog(toHostId(backend), root, Math.trunc(maxCount)))).map(toLogEntry)
);

export const revParse = (backend, root, spec) => (
  toMaybeString(unwrap("revParse", rawRevParse(toHostId(backend), root, spec)))
);

export const showRef = (backend, root) => (
  Array.from(unwrap("showRef", rawShowRef(toHostId(backend), root))).map(toRefInfo)
);

export const merge = (
  backend,
  root,
  target,
  message,
  author,
  timestampSec = Math.floor(Date.now() / 1000),
) => (
  toMergeResult(
    unwrap(
      "merge",
      rawMerge(toHostId(backend), root, target, message, author, Math.trunc(timestampSec)),
    ),
  )
);

export const checkout = (backend, root, target) => {
  unwrap("checkout", rawCheckout(toHostId(backend), root, target));
};

export const checkoutB = (backend, root, branchName) => {
  unwrap("checkoutB", rawCheckoutB(toHostId(backend), root, branchName));
};

export const restore = (backend, root, paths) => {
  unwrap("restore", rawRestore(toHostId(backend), root, Array.from(paths)));
};

export const branchList = (backend, root) => (
  Array.from(unwrap("branchList", rawBranchList(toHostId(backend), root))).map(toBranchInfo)
);

export const branchCreate = (backend, root, name) => {
  unwrap("branchCreate", rawBranchCreate(toHostId(backend), root, name));
};

export const branchDelete = (backend, root, name) => {
  unwrap("branchDelete", rawBranchDelete(toHostId(backend), root, name));
};

export const branchRename = (
  backend,
  root,
  oldName,
  newName,
  options = {},
) => {
  unwrap(
    "branchRename",
    rawBranchRename(
      toHostId(backend),
      root,
      oldName,
      newName,
      Boolean(options.force),
      options.author ?? "Unknown",
      options.email ?? "unknown@localhost",
      Math.trunc(options.timestampSec ?? 0),
      options.timezone ?? "+0000",
    ),
  );
};

export const tagList = (backend, root) => (
  Array.from(unwrap("tagList", rawTagList(toHostId(backend), root)))
);

export const tagDelete = (backend, root, name) => {
  unwrap("tagDelete", rawTagDelete(toHostId(backend), root, name));
};

export const tagCreateLightweight = (
  backend,
  root,
  name,
  target = "HEAD",
) => {
  unwrap(
    "tagCreateLightweight",
    rawTagCreateLightweight(toHostId(backend), root, name, target),
  );
};

export const tagCreateAnnotated = (
  backend,
  root,
  name,
  target,
  message,
  tagger,
  timestampSec = Math.floor(Date.now() / 1000),
) => {
  unwrap(
    "tagCreateAnnotated",
    rawTagCreateAnnotated(
      toHostId(backend),
      root,
      name,
      target,
      message,
      tagger,
      Math.trunc(timestampSec),
    ),
  );
};

export const rebaseStart = (backend, root, upstream) => (
  toRebaseResult(unwrap("rebaseStart", rawRebaseStart(toHostId(backend), root, upstream)))
);

export const rebase = rebaseStart;

export const rebaseStartWithOnto = (backend, root, onto, upstream) => (
  toRebaseResult(
    unwrap(
      "rebaseStartWithOnto",
      rawRebaseStartWithOnto(toHostId(backend), root, onto, upstream),
    ),
  )
);

export const rebaseContinue = (backend, root) => (
  toRebaseResult(unwrap("rebaseContinue", rawRebaseContinue(toHostId(backend), root)))
);

export const rebaseAbort = (backend, root) => {
  unwrap("rebaseAbort", rawRebaseAbort(toHostId(backend), root));
};

export const rebaseSkip = (backend, root) => (
  toRebaseResult(unwrap("rebaseSkip", rawRebaseSkip(toHostId(backend), root)))
);

export const reset = (backend, root, target, mode = "mixed") => (
  unwrap("reset", rawReset(toHostId(backend), root, target, mode))
);

export const stashList = (backend, root) => (
  Array.from(unwrap("stashList", rawStashList(toHostId(backend), root))).map(toStashEntry)
);

export const stashPush = async (
  backend,
  root,
  message,
  author,
  timestampSec = Math.floor(Date.now() / 1000),
) => (
  toMaybeString(
    await unwrapAsync(
      "stashPush",
      rawStashPush(toHostId(backend), root, message, author, Math.trunc(timestampSec)),
    ),
  )
);

export const stashApply = (backend, root, index = 0) => {
  unwrap("stashApply", rawStashApply(toHostId(backend), root, Math.trunc(index), false));
};

export const stashPop = (backend, root, index = 0) => {
  unwrap("stashPop", rawStashApply(toHostId(backend), root, Math.trunc(index), true));
};

export const stashDrop = (backend, root, index = 0) => {
  unwrap("stashDrop", rawStashDrop(toHostId(backend), root, Math.trunc(index)));
};

export const cherryPick = (
  backend,
  root,
  target,
  author,
  options = {},
) => (
  toCherryPickResult(
    unwrap(
      "cherryPick",
      rawCherryPick(
        toHostId(backend),
        root,
        target,
        author,
        Math.trunc(options.timestampSec ?? Math.floor(Date.now() / 1000)),
        Boolean(options.noCommit),
        options.messageSuffix ?? "",
        options.signoffCommitter ?? "",
      ),
    ),
  )
);

export const diffWorktree = async (backend, root) => (
  Array.from(await unwrapAsync("diffWorktree", rawDiffWorktree(toHostId(backend), root)))
);

export const diffWorktreeStat = async (backend, root) => (
  Array.from(await unwrapAsync("diffWorktreeStat", rawDiffWorktreeStat(toHostId(backend), root)))
);

export const diffIndex = (backend, root) => (
  Array.from(unwrap("diffIndex", rawDiffIndex(toHostId(backend), root)))
);

export const diffIndexStat = (backend, root) => (
  Array.from(unwrap("diffIndexStat", rawDiffIndexStat(toHostId(backend), root)))
);

export const listRemotes = (backend, root) => (
  Array.from(unwrap("listRemotes", rawListRemotes(toHostId(backend), root)))
);

export const getRemoteUrl = (backend, root, name) => (
  toMaybeString(unwrap("getRemoteUrl", rawGetRemoteUrl(toHostId(backend), root, name)))
);

export const fetch = async (
  backend,
  root,
  remoteUrl,
  transport,
  options = {},
) => {
  const resolvedRemoteUrl = relayUsesSignaling(remoteUrl)
    ? (await relayResolveRemote(remoteUrl, transport, {
        preferredSender: options.preferredSender ?? null,
        preferredRepo: options.preferredRepo ?? null,
        authToken: options.authToken ?? null,
      })).url
    : remoteUrl;
  return toFetchResult(
    await unwrapAsync(
      "fetch",
      rawFetch(
        toHostId(backend),
        root,
        resolvedRemoteUrl,
        toTransportId(transport),
        options.refspec ?? "",
        options.preferV2 !== false,
      ),
    ),
  );
};

export const push = async (
  backend,
  root,
  remoteUrl,
  transport,
  options = {},
) => {
  const resolvedRemoteUrl = relayUsesSignaling(remoteUrl)
    ? (await relayResolveRemote(remoteUrl, transport, {
        preferredSender: options.preferredSender ?? null,
        preferredRepo: options.preferredRepo ?? null,
        authToken: options.authToken ?? null,
      })).url
    : remoteUrl;
  return unwrapAsync(
    "push",
    rawPush(
      toHostId(backend),
      root,
      resolvedRemoteUrl,
      toTransportId(transport),
      options.refname ?? "",
      Boolean(options.force),
    ),
  );
};

export const rm = (backend, root, paths, options = {}) => {
  unwrap("rm", rawRm(toHostId(backend), root, Array.from(paths), Boolean(options.cached)));
};

export const mv = (backend, root, source, dest) => {
  unwrap("mv", rawMv(toHostId(backend), root, source, dest));
};
