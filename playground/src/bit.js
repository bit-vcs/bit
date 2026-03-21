import {
  add as rawAdd,
  branchCreate as rawBranchCreate,
  branchList as rawBranchList,
  checkout as rawCheckout,
  commit as rawCommit,
  hostReadString as rawHostReadString,
  hostWriteString as rawHostWriteString,
  init as rawInit,
  log as rawLog,
  status as rawStatus,
} from "mbt:mizchi/bit/lib";

const ensureState = () => (
  globalThis.__bitPlaygroundMbtState ??= { nextHostId: 1, hosts: new Map() }
);

const backendHostIds = new WeakMap();

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
    throw new Error(`${label}: ${String(current._0 ?? "bit js error")}`);
  }
  return current;
};

const isBackendObject = (value) => (
  !!value &&
  typeof value === "object" &&
  typeof value.readFile === "function" &&
  typeof value.readdir === "function" &&
  typeof value.isDir === "function" &&
  typeof value.isFile === "function"
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
  if (!isBackendObject(backend)) {
    throw new TypeError("expected bit backend");
  }
  return registerBackend(backend);
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

export const commit = (
  backend,
  root,
  message,
  author,
  timestampSec = Math.floor(Date.now() / 1000),
) => (
  unwrap("commit", rawCommit(toHostId(backend), root, message, author, Math.trunc(timestampSec)))
);

export const log = (backend, root, maxCount = 32) => (
  Array.from(unwrap("log", rawLog(toHostId(backend), root, Math.trunc(maxCount)))).map(toLogEntry)
);

export const checkout = (backend, root, target) => {
  unwrap("checkout", rawCheckout(toHostId(backend), root, target));
};

export const branchList = (backend, root) => (
  Array.from(unwrap("branchList", rawBranchList(toHostId(backend), root))).map(toBranchInfo)
);

export const branchCreate = (backend, root, name) => {
  unwrap("branchCreate", rawBranchCreate(toHostId(backend), root, name));
};
