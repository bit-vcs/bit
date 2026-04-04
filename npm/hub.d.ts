/** VFS host handle (from createMemoryHost). */
interface BitVfsHost {
  _hostId: number;
}

export interface Issue {
  id: string;
  title: string;
  body: string;
  author: string;
  created_at: number;
  updated_at: number;
  state: { $tag: number }; // 0 = Open, 1 = Closed
  labels: string[];
  assignees: string[];
  parent_id: string | null;
  linked_prs: string[];
  linked_issues: string[];
}

export interface IssueComment {
  id: string;
  issue_id: string;
  author: string;
  body: string;
  created_at: number;
  reply_to: string | null;
}

export function hubInit(vfs: BitVfsHost, root: string): void;
export function hubIssueList(vfs: BitVfsHost, root: string, state?: string): Issue[];
export function hubIssueGet(vfs: BitVfsHost, root: string, issueId: string): Issue | null;
export function hubIssueCreate(vfs: BitVfsHost, root: string, opts: {
  title: string;
  body?: string;
  author: string;
  labels?: string[];
  parentId?: string;
}): Issue;
export function hubIssueUpdate(vfs: BitVfsHost, root: string, issueId: string, opts?: {
  title?: string;
  body?: string;
  labels?: string[];
}): Issue;
export function hubIssueClose(vfs: BitVfsHost, root: string, issueId: string): void;
export function hubIssueReopen(vfs: BitVfsHost, root: string, issueId: string): void;
export function hubIssueCommentList(vfs: BitVfsHost, root: string, issueId: string): IssueComment[];
export function hubIssueCommentAdd(vfs: BitVfsHost, root: string, issueId: string, opts: {
  author: string;
  body: string;
}): IssueComment;
export function hubIssueSearch(vfs: BitVfsHost, root: string, query: string, state?: string): Issue[];
