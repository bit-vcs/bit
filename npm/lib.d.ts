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

export interface BitRefInfo {
  name: string;
  id: string;
}

export interface BitRemoteVerboseEntry {
  name: string;
  value: string;
}

export interface BitStashEntry {
  id: string;
  message: string;
}

export type BitMergeStatus =
  | "alreadyUpToDate"
  | "fastForward"
  | "merged"
  | "conflicted";

export interface BitMergeResult {
  status: BitMergeStatus;
  commitId: string | null;
  conflicts: string[];
}

export type BitRebaseStatus =
  | "complete"
  | "conflict"
  | "nothingToRebase";

export interface BitRebaseResult {
  status: BitRebaseStatus;
  commitId: string | null;
  conflicts: string[];
}

export type BitCherryPickStatus = "success" | "conflict";

export interface BitCherryPickResult {
  status: BitCherryPickStatus;
  commitId: string | null;
  conflicts: string[];
}

export type BitFetchStatus = "empty" | "fetched";

export interface BitFetchResult {
  status: BitFetchStatus;
  commitId: string | null;
  refname: string | null;
  remoteRef: string | null;
}

export interface BitRelayPeer {
  sender: string;
  cloneUrl: string;
  repo: string | null;
}

export interface BitResolvedRemote {
  via: "session" | "peer";
  url: string;
  sender: string | null;
  repo: string | null;
  sessionId: string | null;
}

export interface BitTransportResponse {
  status: number;
  body?: Uint8Array | ArrayBuffer | ArrayLike<number> | string | null;
}

export interface BitTransport {
  get(
    url: string,
    headers: Record<string, string>,
  ): BitTransportResponse | Promise<BitTransportResponse>;
  post(
    url: string,
    body: Uint8Array,
    headers: Record<string, string>,
  ): BitTransportResponse | Promise<BitTransportResponse>;
}

export interface BitFetchInit {
  method?: string;
  headers?: Record<string, string>;
  body?: Uint8Array;
}

export interface BitFetchResponse {
  status: number;
  arrayBuffer(): Promise<ArrayBuffer>;
}

export type BitFetchImpl = (
  input: string | URL,
  init?: BitFetchInit,
) => Promise<BitFetchResponse>;

export interface BitRmOptions {
  cached?: boolean;
}

export interface BitBranchRenameOptions {
  force?: boolean;
  author?: string;
  email?: string;
  timestampSec?: number;
  timezone?: string;
}

export interface BitSwitchBranchOptions {
  create?: boolean;
  checkoutFiles?: boolean;
}

export interface BitCommitAmendOptions {
  committer?: string;
  committerTimestampSec?: number;
  timezone?: string;
  encoding?: string;
  authorTimezone?: string;
  committerTimezone?: string;
}

export type BitCommitSigner = (
  payload: string,
) => string | Promise<string>;

export type BitResetMode = "soft" | "mixed" | "hard";

export interface BitFetchOptions {
  refspec?: string;
  preferV2?: boolean;
  preferredSender?: string;
  preferredRepo?: string;
  authToken?: string;
}

export interface BitPushOptions {
  refname?: string;
  force?: boolean;
  preferredSender?: string;
  preferredRepo?: string;
  authToken?: string;
}

export interface BitRelayOptions {
  preferredSender?: string;
  preferredRepo?: string;
  authToken?: string;
}

export interface BitCherryPickOptions {
  noCommit?: boolean;
  messageSuffix?: string;
  signoffCommitter?: string;
  timestampSec?: number;
}

export declare function createMemoryBackend(): BitBackend;
export declare function destroyBackend(backend: BitBackend): void;
export declare function createFetchTransport(fetchImpl: BitFetchImpl): BitTransport;
export declare function relayListClonePeers(
  remoteUrl: string,
  transport: BitTransport | BitFetchImpl,
  options?: Pick<BitRelayOptions, "authToken">,
): Promise<BitRelayPeer[]>;
export declare function relayResolveRemote(
  remoteUrl: string,
  transport: BitTransport | BitFetchImpl,
  options?: BitRelayOptions,
): Promise<BitResolvedRemote>;
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
export declare function statusText(
  backend: BitBackend,
  root: string,
): Promise<string>;
export declare function commit(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): string;
export declare function commitAmend(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  authorTimestampSec?: number,
  options?: BitCommitAmendOptions,
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
export declare function revParse(
  backend: BitBackend,
  root: string,
  spec: string,
): string | null;
export declare function showRef(
  backend: BitBackend,
  root: string,
): BitRefInfo[];
export declare function merge(
  backend: BitBackend,
  root: string,
  target: string,
  message: string,
  author: string,
  timestampSec?: number,
): BitMergeResult;
export declare function checkout(backend: BitBackend, root: string, target: string): void;
export declare function checkoutB(backend: BitBackend, root: string, branchName: string): void;
export declare function switchBranch(
  backend: BitBackend,
  root: string,
  name: string,
  options?: BitSwitchBranchOptions,
): void;
export declare function restore(
  backend: BitBackend,
  root: string,
  paths: Iterable<string> | ArrayLike<string>,
): void;
export declare function branchList(backend: BitBackend, root: string): BitBranchInfo[];
export declare function branchCreate(backend: BitBackend, root: string, name: string): void;
export declare function branchDelete(backend: BitBackend, root: string, name: string): void;
export declare function branchRename(
  backend: BitBackend,
  root: string,
  oldName: string,
  newName: string,
  options?: BitBranchRenameOptions,
): void;
export declare function tagList(backend: BitBackend, root: string): string[];
export declare function tagDelete(
  backend: BitBackend,
  root: string,
  name: string,
): void;
export declare function tagCreateLightweight(
  backend: BitBackend,
  root: string,
  name: string,
  target?: string,
): void;
export declare function tagCreateAnnotated(
  backend: BitBackend,
  root: string,
  name: string,
  target: string,
  message: string,
  tagger: string,
  timestampSec?: number,
): void;
export declare function rebaseStart(
  backend: BitBackend,
  root: string,
  upstream: string,
): BitRebaseResult;
export declare const rebase: typeof rebaseStart;
export declare function rebaseStartWithOnto(
  backend: BitBackend,
  root: string,
  onto: string,
  upstream: string,
): BitRebaseResult;
export declare function rebaseContinue(
  backend: BitBackend,
  root: string,
): BitRebaseResult;
export declare function rebaseAbort(backend: BitBackend, root: string): void;
export declare function rebaseSkip(
  backend: BitBackend,
  root: string,
): BitRebaseResult;
export declare function reset(
  backend: BitBackend,
  root: string,
  target: string,
  mode?: BitResetMode,
): string;
export declare function stashList(
  backend: BitBackend,
  root: string,
): BitStashEntry[];
export declare function stashPush(
  backend: BitBackend,
  root: string,
  message: string,
  author: string,
  timestampSec?: number,
): Promise<string | null>;
export declare function stashApply(
  backend: BitBackend,
  root: string,
  index?: number,
): void;
export declare function stashPop(
  backend: BitBackend,
  root: string,
  index?: number,
): void;
export declare function stashDrop(
  backend: BitBackend,
  root: string,
  index?: number,
): void;
export declare function cherryPick(
  backend: BitBackend,
  root: string,
  target: string,
  author: string,
  options?: BitCherryPickOptions,
): BitCherryPickResult;
export declare function diffWorktree(
  backend: BitBackend,
  root: string,
): Promise<string[]>;
export declare function diffWorktreeStat(
  backend: BitBackend,
  root: string,
): Promise<string[]>;
export declare function diffIndex(
  backend: BitBackend,
  root: string,
): string[];
export declare function diffIndexStat(
  backend: BitBackend,
  root: string,
): string[];
export declare function listRemotes(
  backend: BitBackend,
  root: string,
): string[];
export declare function listRemotesVerbose(
  backend: BitBackend,
  root: string,
): BitRemoteVerboseEntry[];
export declare function getRemoteUrl(
  backend: BitBackend,
  root: string,
  name: string,
): string | null;
export declare function sparseCheckoutInit(
  backend: BitBackend,
  root: string,
  cone?: boolean,
): void;
export declare function sparseCheckoutSet(
  backend: BitBackend,
  root: string,
  patterns: Iterable<string> | ArrayLike<string>,
): void;
export declare function sparseCheckoutAdd(
  backend: BitBackend,
  root: string,
  patterns: Iterable<string> | ArrayLike<string>,
): void;
export declare function sparseCheckoutDisable(
  backend: BitBackend,
  root: string,
): void;
export declare function sparseCheckoutReapply(
  backend: BitBackend,
  root: string,
): void;
export declare function sparseCheckoutEnabled(
  backend: BitBackend,
  root: string,
): boolean;
export declare function sparseCheckoutConeEnabled(
  backend: BitBackend,
  root: string,
): boolean;
export declare function sparseCheckoutPatterns(
  backend: BitBackend,
  root: string,
): string[];
export declare function sparseCheckoutDisplayPatterns(
  backend: BitBackend,
  root: string,
): string[];
export declare function fetch(
  backend: BitBackend,
  root: string,
  remoteUrl: string,
  transport: BitTransport | BitFetchImpl,
  options?: BitFetchOptions,
): Promise<BitFetchResult>;
export declare function push(
  backend: BitBackend,
  root: string,
  remoteUrl: string,
  transport: BitTransport | BitFetchImpl,
  options?: BitPushOptions,
): Promise<string>;
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
