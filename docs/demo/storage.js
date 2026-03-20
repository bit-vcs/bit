const encoder = new TextEncoder();
const decoder = new TextDecoder();

const DB_NAME = "bit-demo-pages";
const DB_VERSION = 1;
const SNAPSHOT_STORE = "snapshots";
const HANDLE_STORE = "handles";
const INDEXED_DB_SNAPSHOT_KEY = "indexeddb-demo-repo";
const FILESYSTEM_HANDLE_KEY = "filesystem-demo-root";
const FILESYSTEM_MANAGED_DIR = ".bit-demo-repo";

export const REPO_ROOT = "/playground";
export const DEFAULT_FILE_PATH = "notes/today.md";
export const DEFAULT_AUTHOR = "Demo User <demo@example.com>";
export const STORAGE_MODES = [
  {
    id: "memory",
    title: "In Memory",
    description: "Fastest loop. Repo disappears when you reload the page.",
    accentClass: "accent-memory",
    accentTone: "volatile",
  },
  {
    id: "indexeddb",
    title: "IndexedDB",
    description: "Persists the repo snapshot inside the browser profile.",
    accentClass: "accent-indexeddb",
    accentTone: "browser-persistent",
  },
  {
    id: "filesystem",
    title: "Local Folder",
    description: "Mirrors the repo into a user-selected directory via File System Access API.",
    accentClass: "accent-filesystem",
    accentTone: "local-folder",
  },
];

const emptySnapshot = () => ({ dirs: ["/"], files: [] });

const normalizePath = (path) => {
  if (path == null || path === "") return "/";
  let normalized = String(path).replace(/\/+/g, "/");
  if (!normalized.startsWith("/")) normalized = `/${normalized}`;
  if (normalized.length > 1 && normalized.endsWith("/")) {
    normalized = normalized.slice(0, -1);
  }
  return normalized;
};

const joinPath = (...parts) => normalizePath(parts.join("/"));

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

const relativeFromRoot = (absolutePath) => {
  const normalized = normalizePath(absolutePath);
  if (normalized === "/") return "";
  return normalized.slice(1);
};

const compareStrings = (left, right) => left.localeCompare(right);

const cloneBytes = (value) => Uint8Array.from(value);

const ensureDirectoryChain = (dirs, path) => {
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

const snapshotToSummary = (snapshot) => {
  const workingFiles = [];
  let gitObjectCount = 0;
  for (const file of snapshot.files) {
    if (file.path.startsWith(`${REPO_ROOT}/.git/objects/`)) {
      gitObjectCount += 1;
      continue;
    }
    if (!file.path.startsWith(`${REPO_ROOT}/.git/`)) {
      workingFiles.push(file.path);
    }
  }
  workingFiles.sort(compareStrings);
  return {
    dirCount: snapshot.dirs.length,
    fileCount: snapshot.files.length,
    gitObjectCount,
    workingFiles,
  };
};

export const createSnapshotHost = () => {
  const files = new Map();
  const dirs = new Set(["/"]);

  const host = {
    mkdirP(path) {
      ensureDirectoryChain(dirs, path);
    },
    writeFile(path, content) {
      const normalized = normalizePath(path);
      ensureDirectoryChain(dirs, parentDir(normalized));
      files.set(normalized, cloneBytes(content));
    },
    writeString(path, content) {
      host.writeFile(path, encoder.encode(String(content)));
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
      return cloneBytes(value);
    },
    readString(path) {
      return decoder.decode(host.readFile(path));
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
      return Array.from(entries).sort(compareStrings);
    },
    isDir(path) {
      return dirs.has(normalizePath(path));
    },
    isFile(path) {
      return files.has(normalizePath(path));
    },
    reset() {
      files.clear();
      dirs.clear();
      dirs.add("/");
    },
    replaceSnapshot(snapshot = emptySnapshot()) {
      host.reset();
      for (const dirPath of snapshot.dirs ?? ["/"]) {
        ensureDirectoryChain(dirs, dirPath);
      }
      for (const file of snapshot.files ?? []) {
        const normalized = normalizePath(file.path);
        ensureDirectoryChain(dirs, parentDir(normalized));
        files.set(normalized, cloneBytes(file.data));
      }
    },
    exportSnapshot() {
      return {
        dirs: Array.from(dirs.values()).sort(compareStrings),
        files: Array.from(files.entries())
          .sort(([left], [right]) => compareStrings(left, right))
          .map(([path, data]) => ({ path, data: cloneBytes(data) })),
      };
    },
    summarizeSnapshot() {
      return snapshotToSummary(host.exportSnapshot());
    },
  };

  return host;
};

const openDemoDatabase = () => new Promise((resolve, reject) => {
  const request = indexedDB.open(DB_NAME, DB_VERSION);
  request.onerror = () => reject(request.error);
  request.onupgradeneeded = () => {
    const db = request.result;
    if (!db.objectStoreNames.contains(SNAPSHOT_STORE)) {
      db.createObjectStore(SNAPSHOT_STORE);
    }
    if (!db.objectStoreNames.contains(HANDLE_STORE)) {
      db.createObjectStore(HANDLE_STORE);
    }
  };
  request.onsuccess = () => resolve(request.result);
});

const withStore = async (storeName, mode, callback) => {
  const db = await openDemoDatabase();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction(storeName, mode);
      const store = transaction.objectStore(storeName);
      let settled = false;
      transaction.onerror = () => {
        if (!settled) {
          settled = true;
          reject(transaction.error);
        }
      };
      transaction.oncomplete = () => {
        if (!settled) {
          settled = true;
          resolve(undefined);
        }
      };
      Promise.resolve(callback(store, transaction)).then((value) => {
        if (value !== undefined && !settled) {
          settled = true;
          resolve(value);
        }
      }).catch((error) => {
        if (!settled) {
          settled = true;
          reject(error);
        }
      });
    });
  } finally {
    db.close();
  }
};

const storeGet = (store, key) => new Promise((resolve, reject) => {
  const request = store.get(key);
  request.onerror = () => reject(request.error);
  request.onsuccess = () => resolve(request.result ?? null);
});

const storePut = (store, value, key) => new Promise((resolve, reject) => {
  const request = store.put(value, key);
  request.onerror = () => reject(request.error);
  request.onsuccess = () => resolve(request.result);
});

const storeDelete = (store, key) => new Promise((resolve, reject) => {
  const request = store.delete(key);
  request.onerror = () => reject(request.error);
  request.onsuccess = () => resolve();
});

const snapshotFromStoredValue = (value) => {
  if (!value) return emptySnapshot();
  return {
    dirs: Array.from(value.dirs ?? ["/"]).map(normalizePath).sort(compareStrings),
    files: Array.from(value.files ?? [])
      .map((file) => ({
        path: normalizePath(file.path),
        data: cloneBytes(file.data),
      }))
      .sort((left, right) => compareStrings(left.path, right.path)),
  };
};

const loadIndexedDbSnapshot = async () => {
  const stored = await withStore(SNAPSHOT_STORE, "readonly", (store) => (
    storeGet(store, INDEXED_DB_SNAPSHOT_KEY)
  ));
  return snapshotFromStoredValue(stored);
};

const saveIndexedDbSnapshot = async (snapshot) => {
  await withStore(SNAPSHOT_STORE, "readwrite", (store) => (
    storePut(store, snapshotFromStoredValue(snapshot), INDEXED_DB_SNAPSHOT_KEY)
  ));
};

const clearIndexedDbSnapshot = async () => {
  await withStore(SNAPSHOT_STORE, "readwrite", (store) => (
    storeDelete(store, INDEXED_DB_SNAPSHOT_KEY)
  ));
};

const storeFileSystemHandle = async (handle) => {
  await withStore(HANDLE_STORE, "readwrite", (store) => (
    storePut(store, handle, FILESYSTEM_HANDLE_KEY)
  ));
};

const loadStoredFileSystemHandle = async () => withStore(
  HANDLE_STORE,
  "readonly",
  (store) => storeGet(store, FILESYSTEM_HANDLE_KEY),
);

const removeStoredFileSystemHandle = async () => {
  await withStore(HANDLE_STORE, "readwrite", (store) => (
    storeDelete(store, FILESYSTEM_HANDLE_KEY)
  ));
};

const isNotFoundError = (error) => error?.name === "NotFoundError";

const queryHandlePermission = async (handle) => {
  if (!handle?.queryPermission) return "granted";
  return handle.queryPermission({ mode: "readwrite" });
};

const requestHandlePermission = async (handle) => {
  if (!handle?.requestPermission) return "granted";
  return handle.requestPermission({ mode: "readwrite" });
};

const getManagedDirectory = async (rootHandle, create = false) => {
  try {
    return await rootHandle.getDirectoryHandle(FILESYSTEM_MANAGED_DIR, { create });
  } catch (error) {
    if (create || !isNotFoundError(error)) throw error;
    return null;
  }
};

const readDirectoryRecursively = async (dirHandle, absolutePath, snapshot) => {
  snapshot.dirs.push(absolutePath);
  for await (const [name, handle] of dirHandle.entries()) {
    const childPath = joinPath(absolutePath, name);
    if (handle.kind === "directory") {
      await readDirectoryRecursively(handle, childPath, snapshot);
      continue;
    }
    const file = await handle.getFile();
    const bytes = new Uint8Array(await file.arrayBuffer());
    snapshot.files.push({ path: childPath, data: bytes });
  }
};

const loadFileSystemSnapshot = async (rootHandle) => {
  if (!rootHandle) return emptySnapshot();
  const managedDir = await getManagedDirectory(rootHandle, false);
  if (!managedDir) return emptySnapshot();
  const snapshot = { dirs: [], files: [] };
  await readDirectoryRecursively(managedDir, "/", snapshot);
  snapshot.dirs.sort(compareStrings);
  snapshot.files.sort((left, right) => compareStrings(left.path, right.path));
  return snapshot;
};

const ensureDirectoryHandle = async (rootHandle, absolutePath) => {
  if (absolutePath === "/") return rootHandle;
  const segments = relativeFromRoot(absolutePath).split("/").filter(Boolean);
  let current = rootHandle;
  for (const segment of segments) {
    current = await current.getDirectoryHandle(segment, { create: true });
  }
  return current;
};

const writeFileSystemSnapshot = async (rootHandle, snapshot) => {
  if (!rootHandle) return;
  try {
    await rootHandle.removeEntry(FILESYSTEM_MANAGED_DIR, { recursive: true });
  } catch (error) {
    if (!isNotFoundError(error)) throw error;
  }
  const managedDir = await getManagedDirectory(rootHandle, true);
  const normalizedSnapshot = snapshotFromStoredValue(snapshot);
  for (const dirPath of normalizedSnapshot.dirs) {
    await ensureDirectoryHandle(managedDir, dirPath);
  }
  for (const file of normalizedSnapshot.files) {
    const dirHandle = await ensureDirectoryHandle(managedDir, parentDir(file.path));
    const fileHandle = await dirHandle.getFileHandle(baseName(file.path), { create: true });
    const writable = await fileHandle.createWritable();
    await writable.write(file.data);
    await writable.close();
  }
};

const clearFileSystemSnapshot = async (rootHandle) => {
  if (!rootHandle) return;
  try {
    await rootHandle.removeEntry(FILESYSTEM_MANAGED_DIR, { recursive: true });
  } catch (error) {
    if (!isNotFoundError(error)) throw error;
  }
};

const createMemoryPersistence = () => ({
  kind: "memory",
  connectLabel: "Memory only",
  async load() {
    return emptySnapshot();
  },
  async save() {},
  async clear() {},
  async connect() {
    return null;
  },
  getBanner() {
    return "Reloading the page drops this repo immediately. Useful for the shortest feedback loop.";
  },
});

const createIndexedDbPersistence = () => ({
  kind: "indexeddb",
  connectLabel: "IndexedDB ready",
  async load() {
    return loadIndexedDbSnapshot();
  },
  async save(snapshot) {
    await saveIndexedDbSnapshot(snapshot);
  },
  async clear() {
    await clearIndexedDbSnapshot();
  },
  async connect() {
    return null;
  },
  getBanner() {
    return "This mode snapshots the repo into IndexedDB after each mutation and restores it on reload.";
  },
});

const createFileSystemPersistence = () => {
  let rootHandle = null;
  let storedHandleName = "";

  return {
    kind: "filesystem",
    connectLabel: "Choose local folder",
    async load() {
      const stored = await loadStoredFileSystemHandle();
      if (!stored) {
        storedHandleName = "";
        rootHandle = null;
        return emptySnapshot();
      }
      storedHandleName = stored.name ?? "";
      const permission = await queryHandlePermission(stored);
      if (permission !== "granted") {
        rootHandle = null;
        return emptySnapshot();
      }
      rootHandle = stored;
      return loadFileSystemSnapshot(rootHandle);
    },
    async save(snapshot) {
      if (!rootHandle) return;
      await writeFileSystemSnapshot(rootHandle, snapshot);
    },
    async clear() {
      await clearFileSystemSnapshot(rootHandle);
    },
    async connect() {
      if (!window.showDirectoryPicker) {
        throw new Error("File System Access API is not available in this browser.");
      }
      const picked = await window.showDirectoryPicker({ mode: "readwrite" });
      const permission = await requestHandlePermission(picked);
      if (permission !== "granted") {
        throw new Error("Folder permission was not granted.");
      }
      rootHandle = picked;
      storedHandleName = picked.name ?? "";
      try {
        await storeFileSystemHandle(picked);
      } catch (error) {
        console.warn("Unable to persist File System handle", error);
      }
      return loadFileSystemSnapshot(rootHandle);
    },
    async disconnect() {
      rootHandle = null;
      storedHandleName = "";
      await removeStoredFileSystemHandle();
    },
    getBanner() {
      if (!window.showDirectoryPicker) {
        return "File System Access API is unavailable here. Use a Chromium-based browser over HTTPS.";
      }
      if (!rootHandle) {
        const suffix = storedHandleName
          ? ` Stored folder: ${storedHandleName}. Click connect to re-grant access.`
          : "";
        return `Pick a folder and this demo will mirror the repo into ${FILESYSTEM_MANAGED_DIR}/${suffix}`;
      }
      return `Mirroring repo contents into ${rootHandle.name}/${FILESYSTEM_MANAGED_DIR}/`;
    },
    get connectedName() {
      return rootHandle?.name ?? storedHandleName;
    },
    get isConnected() {
      return Boolean(rootHandle);
    },
  };
};

const createPersistence = (id) => {
  if (id === "indexeddb") return createIndexedDbPersistence();
  if (id === "filesystem") return createFileSystemPersistence();
  return createMemoryPersistence();
};

export const createStorageControllers = () => STORAGE_MODES.map((mode) => {
  const host = createSnapshotHost();
  const persistence = createPersistence(mode.id);

  return {
    ...mode,
    host,
    persistence,
    ready: false,
    saving: false,
    lastSavedAt: null,
    lastLoadedAt: null,
    async hydrate() {
      const snapshot = await persistence.load();
      host.replaceSnapshot(snapshot);
      this.ready = true;
      this.lastLoadedAt = new Date();
      return host.summarizeSnapshot();
    },
    async persist() {
      this.saving = true;
      try {
        await persistence.save(host.exportSnapshot());
        this.lastSavedAt = new Date();
      } finally {
        this.saving = false;
      }
      return host.summarizeSnapshot();
    },
    async clear() {
      await persistence.clear();
      host.reset();
      this.lastSavedAt = new Date();
      return host.summarizeSnapshot();
    },
    async connect() {
      const snapshot = await persistence.connect();
      if (snapshot) {
        host.replaceSnapshot(snapshot);
        this.ready = true;
        this.lastLoadedAt = new Date();
      }
      return host.summarizeSnapshot();
    },
    async disconnect() {
      if (typeof persistence.disconnect === "function") {
        await persistence.disconnect();
      }
      host.reset();
      this.ready = true;
      this.lastLoadedAt = new Date();
      return host.summarizeSnapshot();
    },
    summarize() {
      return host.summarizeSnapshot();
    },
    getBanner() {
      return persistence.getBanner();
    },
    isRepoInitialized() {
      return host.isDir(joinPath(REPO_ROOT, ".git"));
    },
  };
});

export const absoluteFilePath = (relativePath) => joinPath(REPO_ROOT, relativePath);

export const summarizeWorkingSnapshot = (host) => host.summarizeSnapshot();

export const timestampLabel = (value) => (
  value
    ? new Intl.DateTimeFormat(undefined, {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).format(value)
    : "not yet saved"
);
