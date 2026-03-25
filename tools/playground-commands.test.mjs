import assert from "node:assert/strict";
import test from "node:test";

import { runPlaygroundCommand, tokenizeCommand } from "../playground/src/commands.js";

const createFakeApp = () => {
  const calls = [];
  const state = {
    editor: {
      path: "notes/today.md",
    },
    view: {
      currentStatus: {
        stagedAdded: [],
        stagedModified: [],
        stagedDeleted: [],
        unstagedModified: ["notes/today.md"],
        unstagedDeleted: [],
        untracked: [],
      },
    },
  };

  return {
    calls,
    getEditor() {
      return state.editor;
    },
    getView() {
      return state.view;
    },
    listFiles() {
      calls.push(["listFiles"]);
      return ["README.md", "notes/today.md"];
    },
    async openFile(path) {
      calls.push(["openFile", path]);
      state.editor.path = path;
    },
    async saveEditor() {
      calls.push(["saveEditor"]);
    },
    async stagePaths(paths) {
      calls.push(["stagePaths", paths]);
    },
    async commit(message) {
      calls.push(["commit", message]);
      return "1234567890abcdef";
    },
    listHistory(count) {
      calls.push(["listHistory", count]);
      return [{ id: "1234567890abcdef", message: "demo: update notes" }];
    },
    listBranches() {
      calls.push(["listBranches"]);
      return [
        { name: "main", isCurrent: true },
        { name: "feature/demo", isCurrent: false },
      ];
    },
    async createBranch(name) {
      calls.push(["createBranch", name]);
    },
    async checkoutBranch(name) {
      calls.push(["checkoutBranch", name]);
    },
    async startHosting(label) {
      calls.push(["startHosting", label]);
      return { sessionId: "sess-a", label: label ?? "host-a" };
    },
    async refreshSessions() {
      calls.push(["refreshSessions"]);
      return [
        { sessionId: "sess-a", label: "Host A", lastRevision: 3 },
      ];
    },
    async connectSession(sessionId) {
      calls.push(["connectSession", sessionId]);
    },
    async pullConnectedSession() {
      calls.push(["pullConnectedSession"]);
      return true;
    },
    async resetSampleRepo() {
      calls.push(["resetSampleRepo"]);
    },
  };
};

test("tokenizeCommand handles spaces, quotes, and backslash escaping", () => {
  assert.deepEqual(tokenizeCommand("commit demo"), ["commit", "demo"]);
  assert.deepEqual(tokenizeCommand("commit \"demo update\""), ["commit", "demo update"]);
  assert.deepEqual(tokenizeCommand("open notes\\/today.md"), ["open", "notes/today.md"]);
});

test("help and status return user-facing lines", async () => {
  const app = createFakeApp();
  const help = await runPlaygroundCommand(app, "help");
  const status = await runPlaygroundCommand(app, "status");

  assert.equal(help.ok, true);
  assert.ok(help.lines.includes("commit <message>"));
  assert.equal(status.ok, true);
  assert.deepEqual(status.lines, ["unstaged modified:", "  notes/today.md"]);
});

test("open, save, add, commit, and branch commands delegate to app contract", async () => {
  const app = createFakeApp();

  const open = await runPlaygroundCommand(app, "open README.md");
  const save = await runPlaygroundCommand(app, "save");
  const add = await runPlaygroundCommand(app, "add");
  const commit = await runPlaygroundCommand(app, "commit demo: update readme");
  const branch = await runPlaygroundCommand(app, "branch feature/new-ui");
  const checkout = await runPlaygroundCommand(app, "checkout feature/new-ui");

  assert.deepEqual(open, { ok: true, lines: ["opened README.md"] });
  assert.deepEqual(save, { ok: true, lines: ["saved README.md"] });
  assert.deepEqual(add, { ok: true, lines: ["staged README.md"] });
  assert.deepEqual(commit, { ok: true, lines: ["committed 1234567 demo: update readme"] });
  assert.deepEqual(branch, { ok: true, lines: ["created branch feature/new-ui"] });
  assert.deepEqual(checkout, { ok: true, lines: ["checked out feature/new-ui"] });
  assert.deepEqual(app.calls, [
    ["openFile", "README.md"],
    ["saveEditor"],
    ["stagePaths", ["README.md"]],
    ["commit", "demo: update readme"],
    ["createBranch", "feature/new-ui"],
    ["checkoutBranch", "feature/new-ui"],
  ]);
});

test("relay and history commands surface session state", async () => {
  const app = createFakeApp();

  const log = await runPlaygroundCommand(app, "log 5");
  const branches = await runPlaygroundCommand(app, "branches");
  const host = await runPlaygroundCommand(app, "relay host Host A");
  const sessions = await runPlaygroundCommand(app, "relay sessions");
  const connect = await runPlaygroundCommand(app, "relay connect sess-a");
  const pull = await runPlaygroundCommand(app, "relay pull");

  assert.deepEqual(log, { ok: true, lines: ["1234567 demo: update notes"] });
  assert.deepEqual(branches, { ok: true, lines: ["* main", "  feature/demo"] });
  assert.deepEqual(host, { ok: true, lines: ["hosting sess-a Host A"] });
  assert.deepEqual(sessions, { ok: true, lines: ["sess-a  Host A  rev:3"] });
  assert.deepEqual(connect, { ok: true, lines: ["connected sess-a"] });
  assert.deepEqual(pull, { ok: true, lines: ["pulled latest snapshot"] });
});

test("command errors are returned as failed results", async () => {
  const app = createFakeApp();

  const emptyCommit = await runPlaygroundCommand(app, "commit");
  const unknown = await runPlaygroundCommand(app, "wat");

  assert.deepEqual(emptyCommit, { ok: false, lines: ["commit requires a message"] });
  assert.deepEqual(unknown, { ok: false, lines: ["unknown command: wat"] });
});
