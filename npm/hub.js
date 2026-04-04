// Hub (issue/PR) operations - JS wrapper around MoonBit hub module.
// Shares globalThis.__bitGitJsState with lib.js for host VFS bridge.
import {
  hubIssueInit as rawHubIssueInit,
  hubIssueList as rawHubIssueList,
  hubIssueGet as rawHubIssueGet,
  hubIssueCreate as rawHubIssueCreate,
  hubIssueUpdate as rawHubIssueUpdate,
  hubIssueClose as rawHubIssueClose,
  hubIssueReopen as rawHubIssueReopen,
  hubIssueCommentList as rawHubIssueCommentList,
  hubIssueCommentAdd as rawHubIssueCommentAdd,
  hubIssueSearch as rawHubIssueSearch,
} from "./hub.raw.js";

function unwrap(result) {
  if (result._tag === "Err" || result.$tag === 1) {
    const msg = result._0 ?? result.val ?? "unknown error";
    throw new Error(msg);
  }
  return result._0 ?? result.val;
}

/** Initialize hub metadata in a repository. */
export function hubInit(vfs, root) {
  unwrap(rawHubIssueInit(vfs._hostId, root));
}

/** List issues. state: "open" | "closed" | "" (all). */
export function hubIssueList(vfs, root, state = "") {
  return unwrap(rawHubIssueList(vfs._hostId, root, state));
}

/** Get an issue by ID. Returns issue object or null. */
export function hubIssueGet(vfs, root, issueId) {
  const result = unwrap(rawHubIssueGet(vfs._hostId, root, issueId));
  // MoonBit Option: { $tag: 0 } = None, { $tag: 1, _0: value } = Some
  if (result && result.$tag === 1) return result._0;
  if (result && result.$tag === 0) return null;
  return result ?? null;
}

/** Create an issue. Returns the created issue. */
export function hubIssueCreate(vfs, root, { title, body = "", author, labels = [], parentId = "" }) {
  return unwrap(rawHubIssueCreate(vfs._hostId, root, title, body, author, labels, parentId));
}

/** Update an issue. Only non-empty fields are updated. */
export function hubIssueUpdate(vfs, root, issueId, { title = "", body = "", labels = [] } = {}) {
  return unwrap(rawHubIssueUpdate(vfs._hostId, root, issueId, title, body, labels));
}

/** Close an issue. */
export function hubIssueClose(vfs, root, issueId) {
  unwrap(rawHubIssueClose(vfs._hostId, root, issueId));
}

/** Reopen a closed issue. */
export function hubIssueReopen(vfs, root, issueId) {
  unwrap(rawHubIssueReopen(vfs._hostId, root, issueId));
}

/** List comments on an issue. */
export function hubIssueCommentList(vfs, root, issueId) {
  return unwrap(rawHubIssueCommentList(vfs._hostId, root, issueId));
}

/** Add a comment to an issue. */
export function hubIssueCommentAdd(vfs, root, issueId, { author, body }) {
  return unwrap(rawHubIssueCommentAdd(vfs._hostId, root, issueId, author, body));
}

/** Search issues by query string. */
export function hubIssueSearch(vfs, root, query, state = "") {
  return unwrap(rawHubIssueSearch(vfs._hostId, root, query, state));
}
