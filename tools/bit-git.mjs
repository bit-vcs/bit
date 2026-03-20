import {
  add as rawAdd,
  branchCreate as rawBranchCreate,
  branchDelete as rawBranchDelete,
  branchList as rawBranchList,
  buildCommitPayload as rawBuildCommitPayload,
  checkout as rawCheckout,
  checkoutB as rawCheckoutB,
  commit as rawCommit,
  commitSigned as rawCommitSigned,
  destroyHost as rawDestroyHost,
  hostReadString as rawHostReadString,
  hostWriteString as rawHostWriteString,
  init as rawInit,
  log as rawLog,
  mv as rawMv,
  rm as rawRm,
  status as rawStatus,
  statusPorcelain as rawStatusPorcelain,
} from "../_build/js/release/build/lib/lib.js";

const ensureState = () => (
  globalThis.__bitGitJsState ??= { nextHostId: 1, hosts: new Map() }
);

const backendHostIds = new WeakMap();

const unwrap = (label, result) => {
  if (result && typeof result === "object" && "$tag" in result) {
    if (result.$tag === 1) {
      return result._0;
    }
    throw new Error(`${label}: ${String(result._0 ?? "bit-git js error")}`);
  }
  throw new TypeError(`${label}: invalid MoonBit result`);
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
  if (isBackendObject(backend)) {
    return registerBackend(backend);
  }
  throw new TypeError("expected BitGit backend");
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

export const checkout = (backend, root, target) => {
  unwrap("checkout", rawCheckout(toHostId(backend), root, target));
};

export const checkoutB = (backend, root, branchName) => {
  unwrap("checkoutB", rawCheckoutB(toHostId(backend), root, branchName));
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

export const rm = (backend, root, paths, options = {}) => {
  unwrap("rm", rawRm(toHostId(backend), root, Array.from(paths), Boolean(options.cached)));
};

export const mv = (backend, root, source, dest) => {
  unwrap("mv", rawMv(toHostId(backend), root, source, dest));
};
