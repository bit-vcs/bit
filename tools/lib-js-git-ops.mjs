import {
  add,
  branchCreate,
  branchDelete,
  branchList,
  checkout,
  checkoutB,
  commit,
  destroyBackend,
  init,
  log,
  mv,
  readString,
  rm,
  status,
  statusPorcelain,
  writeString,
} from "./bit-git.mjs";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function branchNames(branches) {
  return branches.map((branch) => branch.name).sort();
}

function createVirtualHost() {
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
}

const root = "/repo";
const backend = createVirtualHost();

try {
  init(backend, root, "main");
  assert(statusPorcelain(backend, root).length === 0, "repo should start clean");

  writeString(backend, `${root}/README.md`, "# repo\n");

  const beforeAdd = status(backend, root);
  assert(beforeAdd.untracked.includes("README.md"), "README.md should be untracked");

  add(backend, root, ["README.md"]);
  const firstCommit = commit(
    backend, root, "initial commit", "Bundle Demo <bundle@example.com>", 1700000000,
  );
  assert(firstCommit.length === 40, "initial commit id should be sha1 hex");

  branchCreate(backend, root, "topic");
  let branches = branchList(backend, root);
  assert(branchNames(branches).join(",") === "main,topic", "main/topic branches should exist");
  assert(branches.some((branch) => branch.name === "main" && branch.isCurrent), "main should be current");

  checkoutB(backend, root, "feature");
  branches = branchList(backend, root);
  assert(
    branchNames(branches).join(",") === "feature,main,topic",
    "feature/main/topic branches should exist",
  );
  assert(
    branches.some((branch) => branch.name === "feature" && branch.isCurrent),
    "feature should be current",
  );

  branchDelete(backend, root, "topic");
  branches = branchList(backend, root);
  assert(branchNames(branches).join(",") === "feature,main", "topic should be deleted");

  writeString(backend, `${root}/notes.txt`, "notes\n");
  add(backend, root, ["notes.txt"]);
  const secondCommit = commit(
    backend, root, "add notes", "Bundle Demo <bundle@example.com>", 1700000060,
  );
  assert(secondCommit.length === 40, "second commit id should be sha1 hex");

  mv(backend, root, "notes.txt", "memo.txt");
  const afterMove = status(backend, root);
  assert(afterMove.stagedAdded.includes("memo.txt"), "memo.txt should be staged after mv");
  assert(afterMove.stagedDeleted.includes("notes.txt"), "notes.txt should be staged deleted after mv");

  const thirdCommit = commit(
    backend, root, "rename notes", "Bundle Demo <bundle@example.com>", 1700000120,
  );
  assert(thirdCommit.length === 40, "third commit id should be sha1 hex");

  rm(backend, root, ["memo.txt"]);
  const afterRm = status(backend, root);
  assert(afterRm.stagedDeleted.includes("memo.txt"), "memo.txt should be staged deleted after rm");

  const fourthCommit = commit(
    backend, root, "remove memo", "Bundle Demo <bundle@example.com>", 1700000180,
  );
  assert(fourthCommit.length === 40, "fourth commit id should be sha1 hex");

  checkout(backend, root, "main");
  let head = readString(backend, `${root}/.git/HEAD`);
  assert(head === "ref: refs/heads/main\n", "HEAD should point to main");

  checkout(backend, root, "feature");
  head = readString(backend, `${root}/.git/HEAD`);
  assert(head === "ref: refs/heads/feature\n", "HEAD should point to feature");

  const logEntries = log(backend, root, 10);
  assert(logEntries.length === 4, "expected 4 commits in log");
  assert(logEntries[0].message === "remove memo", "latest commit should be remove memo");

  console.log(
    JSON.stringify(
      {
        firstCommit,
        secondCommit,
        thirdCommit,
        fourthCommit,
        branches,
        logEntries,
      },
      null,
      2,
    ),
  );
} finally {
  destroyBackend(backend);
}
