import assert from "node:assert/strict";
import test from "node:test";

import {
  STATUS_GROUPS,
  createTerminalBuffer,
  quoteArgument,
  renderBranchListHtml,
  renderFilesListHtml,
  renderHistoryListHtml,
  renderRelaySessionsHtml,
  renderStatusListHtml,
} from "../playground/src/view.js";

test("quoteArgument escapes quotes and backslashes", () => {
  assert.equal(quoteArgument("notes/today.md"), "\"notes/today.md\"");
  assert.equal(
    quoteArgument("say \"hi\" \\ now"),
    "\"say \\\"hi\\\" \\\\ now\"",
  );
});

test("render list helpers return empty state copy when nothing is available", () => {
  assert.match(renderFilesListHtml([], "notes/today.md"), /No files yet/);
  assert.match(renderStatusListHtml({}, STATUS_GROUPS), /Working tree clean/);
  assert.match(renderHistoryListHtml([]), /No commits yet/);
  assert.match(renderBranchListHtml([]), /No branches yet/);
  assert.match(renderRelaySessionsHtml({ sessions: [] }), /No hosted editors/);
});

test("render list helpers include current selections and escaped content", () => {
  const filesHtml = renderFilesListHtml(["README.md", "notes/<today>.md"], "notes/<today>.md");
  const statusHtml = renderStatusListHtml({
    stagedAdded: ["README.md"],
    untracked: ["notes/<today>.md"],
  }, STATUS_GROUPS);
  const historyHtml = renderHistoryListHtml([
    {
      id: "0123456789abcdef",
      timestamp: 1_700_000_000,
      message: "demo <seed>",
      author: "Demo <demo@example.com>",
    },
  ]);
  const branchesHtml = renderBranchListHtml([
    { name: "main", isCurrent: true },
    { name: "feature/demo", isCurrent: false },
  ]);
  const relayHtml = renderRelaySessionsHtml({
    selectedSessionId: "sess-2",
    sessions: [
      { sessionId: "sess-1", label: "Host <A>" },
      { sessionId: "sess-2", label: "Host B" },
    ],
  });

  assert.match(filesHtml, /is-current/);
  assert.match(filesHtml, /notes\/&lt;today&gt;\.md/);
  assert.match(statusHtml, /Staged Added/);
  assert.match(statusHtml, /Untracked/);
  assert.match(historyHtml, /demo &lt;seed&gt;/);
  assert.match(historyHtml, /Demo &lt;demo@example\.com&gt;/);
  assert.match(branchesHtml, /current/);
  assert.match(relayHtml, /data-session-id="sess-2"/);
  assert.match(relayHtml, /is-current/);
});

test("terminal buffer keeps recent entries and escapes rendered html", () => {
  const terminal = createTerminalBuffer(3);
  terminal.push(["<ready>"], "info");
  terminal.push(["ok"], "ok");
  terminal.push(["warn"], "error");
  terminal.push(["prompt"], "prompt");

  const entries = terminal.snapshot();
  assert.equal(entries.length, 3);
  assert.deepEqual(entries.map((entry) => entry.line), ["ok", "warn", "prompt"]);
  assert.match(terminal.renderHtml(), /&lt;|prompt/);
  assert.doesNotMatch(terminal.renderHtml(), /<ready>/);
});
