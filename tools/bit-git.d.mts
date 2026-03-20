export interface BitGitBackend {
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

export type BitGitHost = BitGitBackend;

export interface BitGitStatus {
  stagedAdded: string[];
  stagedModified: string[];
  stagedDeleted: string[];
  unstagedModified: string[];
  unstagedDeleted: string[];
  untracked: string[];
}

export interface BitGitBranchInfo {
  name: string;
  commitId: string;
  isCurrent: boolean;
}

export interface BitGitLogEntry {
  id: string;
  author: string;
  message: string;
  timestamp: number;
}

export interface BitGitRmOptions {
  cached?: boolean;
}

export type BitGitCommitSigner = (
  payload: string,
) => string | Promise<string>;

export declare function createMemoryHost(): BitGitBackend;
export declare function destroyHost(backend: BitGitBackend): void;
export declare function writeString(backend: BitGitBackend, path: string, content: string): void;
export declare function readString(backend: BitGitBackend, path: string): string;
export declare function init(backend: BitGitBackend, root: string, defaultBranch?: string): void;
export declare function add(
  backend: BitGitBackend,
  root: string,
  paths: Iterable<string> | ArrayLike<string>,
): void;
export declare function status(backend: BitGitBackend, root: string): BitGitStatus;
export declare function statusPorcelain(backend: BitGitBackend, root: string): string[];
export declare function commit(
  backend: BitGitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): string;
export declare function buildCommitPayload(
  backend: BitGitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): string;
export declare function commitSigned(
  backend: BitGitBackend,
  root: string,
  message: string,
  author: string,
  signature: string,
  timestampSec?: number,
): string;
export declare function commitWithSigner(
  backend: BitGitBackend,
  root: string,
  message: string,
  author: string,
  signer: BitGitCommitSigner,
  timestampSec?: number,
): Promise<string>;
export declare function log(
  backend: BitGitBackend,
  root: string,
  maxCount?: number,
): BitGitLogEntry[];
export declare function checkout(backend: BitGitBackend, root: string, target: string): void;
export declare function checkoutB(backend: BitGitBackend, root: string, branchName: string): void;
export declare function branchList(backend: BitGitBackend, root: string): BitGitBranchInfo[];
export declare function branchCreate(backend: BitGitBackend, root: string, name: string): void;
export declare function branchDelete(backend: BitGitBackend, root: string, name: string): void;
export declare function rm(
  backend: BitGitBackend,
  root: string,
  paths: Iterable<string> | ArrayLike<string>,
  options?: BitGitRmOptions,
): void;
export declare function mv(
  backend: BitGitBackend,
  root: string,
  source: string,
  dest: string,
): void;
