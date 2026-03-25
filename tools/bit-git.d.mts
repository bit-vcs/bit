export interface BitBackend {
  mkdirP(path: string): void;
  writeFile(path: string, content: Uint8Array): void;
  writeString(path: string, content: string): void;
  removeFile(path: string): void;
  removeDir(path: string): void;
  readFile(path: string): Uint8Array | ArrayBuffer | ArrayLike<number> | string;
  readdir(path: string): Iterable<string> | ArrayLike<string>;
  isDir(path: string): boolean;
  isFile(path: string): boolean;
}

export type BitHost = BitBackend;

export interface BitStatus {
  stagedAdded: string[];
  stagedModified: string[];
  stagedDeleted: string[];
  unstagedModified: string[];
  unstagedDeleted: string[];
  untracked: string[];
}

export interface BitBranchInfo {
  name: string;
  commitId: string;
  isCurrent: boolean;
}

export interface BitLogEntry {
  id: string;
  author: string;
  message: string;
  timestamp: number;
}

export interface BitRmOptions {
  cached?: boolean;
}

export type BitCommitSigner = (
  payload: string,
) => string | Promise<string>;

export declare function createMemoryBackend(): BitBackend;
export declare function destroyBackend(backend: BitBackend): void;
export declare function writeString(backend: BitBackend, path: string, content: string): void;
export declare function readString(backend: BitBackend, path: string): string;
export declare function init(backend: BitBackend, root: string, defaultBranch?: string): void;
export declare function add(
  backend: BitBackend,
  root: string,
  paths: Iterable<string> | ArrayLike<string>,
): void;
export declare function status(backend: BitBackend, root: string): BitStatus;
export declare function statusPorcelain(backend: BitBackend, root: string): string[];
export declare function commit(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): string;
export declare function buildCommitPayload(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): string;
export declare function commitSigned(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  signature: string,
  timestampSec?: number,
): string;
export declare function commitWithSigner(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  signer: BitCommitSigner,
  timestampSec?: number,
): Promise<string>;
export declare function log(
  backend: BitBackend,
  root: string,
  maxCount?: number,
): BitLogEntry[];
export declare function checkout(backend: BitBackend, root: string, target: string): void;
export declare function checkoutB(backend: BitBackend, root: string, branchName: string): void;
export declare function branchList(backend: BitBackend, root: string): BitBranchInfo[];
export declare function branchCreate(backend: BitBackend, root: string, name: string): void;
export declare function branchDelete(backend: BitBackend, root: string, name: string): void;
export declare function rm(
  backend: BitBackend,
  root: string,
  paths: Iterable<string> | ArrayLike<string>,
  options?: BitRmOptions,
): void;
export declare function mv(
  backend: BitBackend,
  root: string,
  source: string,
  dest: string,
): void;
