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

export interface BitGitRefInfo {
  name: string;
  id: string;
}

export interface BitGitStashEntry {
  id: string;
  message: string;
}

export type BitGitMergeStatus =
  | "alreadyUpToDate"
  | "fastForward"
  | "merged"
  | "conflicted";

export interface BitGitMergeResult {
  status: BitGitMergeStatus;
  commitId: string | null;
  conflicts: string[];
}

export type BitGitRebaseStatus =
  | "complete"
  | "conflict"
  | "nothingToRebase";

export interface BitGitRebaseResult {
  status: BitGitRebaseStatus;
  commitId: string | null;
  conflicts: string[];
}

export type BitGitCherryPickStatus = "success" | "conflict";

export interface BitGitCherryPickResult {
  status: BitGitCherryPickStatus;
  commitId: string | null;
  conflicts: string[];
}

export type BitGitFetchStatus = "empty" | "fetched";

export interface BitGitFetchResult {
  status: BitGitFetchStatus;
  commitId: string | null;
  refname: string | null;
  remoteRef: string | null;
}

export interface BitGitRelayPeer {
  sender: string;
  cloneUrl: string;
  repo: string | null;
}

export interface BitGitResolvedRemote {
  via: "session" | "peer";
  url: string;
  sender: string | null;
  repo: string | null;
  sessionId: string | null;
}

export interface BitGitTransportResponse {
  status: number;
  body?: Uint8Array | ArrayBuffer | ArrayLike<number> | string | null;
}

export interface BitGitTransport {
  get(
    url: string,
    headers: Record<string, string>,
  ): BitGitTransportResponse | Promise<BitGitTransportResponse>;
  post(
    url: string,
    body: Uint8Array,
    headers: Record<string, string>,
  ): BitGitTransportResponse | Promise<BitGitTransportResponse>;
}

export interface BitGitFetchInit {
  method?: string;
  headers?: Record<string, string>;
  body?: Uint8Array;
}

export interface BitGitFetchResponse {
  status: number;
  arrayBuffer(): Promise<ArrayBuffer>;
}

export type BitGitFetchImpl = (
  input: string | URL,
  init?: BitGitFetchInit,
) => Promise<BitGitFetchResponse>;

export interface BitGitRmOptions {
  cached?: boolean;
}

export interface BitGitBranchRenameOptions {
  force?: boolean;
  author?: string;
  email?: string;
  timestampSec?: number;
  timezone?: string;
}

export type BitGitCommitSigner = (
  payload: string,
) => string | Promise<string>;

export type BitGitResetMode = "soft" | "mixed" | "hard";

export interface BitGitFetchOptions {
  refspec?: string;
  preferV2?: boolean;
  preferredSender?: string;
  preferredRepo?: string;
  authToken?: string;
}

export interface BitGitPushOptions {
  refname?: string;
  force?: boolean;
  preferredSender?: string;
  preferredRepo?: string;
  authToken?: string;
}

export interface BitGitRelayOptions {
  preferredSender?: string;
  preferredRepo?: string;
  authToken?: string;
}

export interface BitGitCherryPickOptions {
  noCommit?: boolean;
  messageSuffix?: string;
  signoffCommitter?: string;
  timestampSec?: number;
}

export declare function createMemoryHost(): BitGitBackend;
export declare function destroyHost(backend: BitGitBackend): void;
export declare function createFetchTransport(fetchImpl: BitGitFetchImpl): BitGitTransport;
export declare function relayListClonePeers(
  remoteUrl: string,
  transport: BitGitTransport | BitGitFetchImpl,
  options?: Pick<BitGitRelayOptions, "authToken">,
): Promise<BitGitRelayPeer[]>;
export declare function relayResolveRemote(
  remoteUrl: string,
  transport: BitGitTransport | BitGitFetchImpl,
  options?: BitGitRelayOptions,
): Promise<BitGitResolvedRemote>;
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
export declare function revParse(
  backend: BitGitBackend,
  root: string,
  spec: string,
): string | null;
export declare function showRef(
  backend: BitGitBackend,
  root: string,
): BitGitRefInfo[];
export declare function merge(
  backend: BitGitBackend,
  root: string,
  target: string,
  message: string,
  author: string,
  timestampSec?: number,
): BitGitMergeResult;
export declare function checkout(backend: BitGitBackend, root: string, target: string): void;
export declare function checkoutB(backend: BitGitBackend, root: string, branchName: string): void;
export declare function restore(
  backend: BitGitBackend,
  root: string,
  paths: Iterable<string> | ArrayLike<string>,
): void;
export declare function branchList(backend: BitGitBackend, root: string): BitGitBranchInfo[];
export declare function branchCreate(backend: BitGitBackend, root: string, name: string): void;
export declare function branchDelete(backend: BitGitBackend, root: string, name: string): void;
export declare function branchRename(
  backend: BitGitBackend,
  root: string,
  oldName: string,
  newName: string,
  options?: BitGitBranchRenameOptions,
): void;
export declare function tagList(backend: BitGitBackend, root: string): string[];
export declare function tagDelete(
  backend: BitGitBackend,
  root: string,
  name: string,
): void;
export declare function tagCreateLightweight(
  backend: BitGitBackend,
  root: string,
  name: string,
  target?: string,
): void;
export declare function tagCreateAnnotated(
  backend: BitGitBackend,
  root: string,
  name: string,
  target: string,
  message: string,
  tagger: string,
  timestampSec?: number,
): void;
export declare function rebaseStart(
  backend: BitGitBackend,
  root: string,
  upstream: string,
): BitGitRebaseResult;
export declare const rebase: typeof rebaseStart;
export declare function rebaseStartWithOnto(
  backend: BitGitBackend,
  root: string,
  onto: string,
  upstream: string,
): BitGitRebaseResult;
export declare function rebaseContinue(
  backend: BitGitBackend,
  root: string,
): BitGitRebaseResult;
export declare function rebaseAbort(backend: BitGitBackend, root: string): void;
export declare function rebaseSkip(
  backend: BitGitBackend,
  root: string,
): BitGitRebaseResult;
export declare function reset(
  backend: BitGitBackend,
  root: string,
  target: string,
  mode?: BitGitResetMode,
): string;
export declare function stashList(
  backend: BitGitBackend,
  root: string,
): BitGitStashEntry[];
export declare function stashPush(
  backend: BitGitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): Promise<string | null>;
export declare function stashApply(
  backend: BitGitBackend,
  root: string,
  index?: number,
): void;
export declare function stashPop(
  backend: BitGitBackend,
  root: string,
  index?: number,
): void;
export declare function stashDrop(
  backend: BitGitBackend,
  root: string,
  index?: number,
): void;
export declare function cherryPick(
  backend: BitGitBackend,
  root: string,
  target: string,
  author: string,
  options?: BitGitCherryPickOptions,
): BitGitCherryPickResult;
export declare function diffWorktree(
  backend: BitGitBackend,
  root: string,
): Promise<string[]>;
export declare function diffWorktreeStat(
  backend: BitGitBackend,
  root: string,
): Promise<string[]>;
export declare function diffIndex(
  backend: BitGitBackend,
  root: string,
): string[];
export declare function diffIndexStat(
  backend: BitGitBackend,
  root: string,
): string[];
export declare function listRemotes(
  backend: BitGitBackend,
  root: string,
): string[];
export declare function getRemoteUrl(
  backend: BitGitBackend,
  root: string,
  name: string,
): string | null;
export declare function fetch(
  backend: BitGitBackend,
  root: string,
  remoteUrl: string,
  transport: BitGitTransport | BitGitFetchImpl,
  options?: BitGitFetchOptions,
): Promise<BitGitFetchResult>;
export declare function push(
  backend: BitGitBackend,
  root: string,
  remoteUrl: string,
  transport: BitGitTransport | BitGitFetchImpl,
  options?: BitGitPushOptions,
): Promise<string>;
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
