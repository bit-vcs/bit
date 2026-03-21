import { runPlaygroundCommand } from "./commands.js";
import { STATUS_GROUPS, createPlaygroundApp } from "./state.js";

const app = createPlaygroundApp();

const elements = {
  heroMeta: document.querySelector("#hero-meta"),
  storageBanner: document.querySelector("#storage-banner"),
  resetRepo: document.querySelector("#reset-repo"),
  filePath: document.querySelector("#file-path"),
  fileContent: document.querySelector("#file-content"),
  openFile: document.querySelector("#open-file"),
  saveFile: document.querySelector("#save-file"),
  stageFile: document.querySelector("#stage-file"),
  commitMessage: document.querySelector("#commit-message"),
  commitFile: document.querySelector("#commit-file"),
  branchName: document.querySelector("#branch-name"),
  createBranch: document.querySelector("#create-branch"),
  checkoutBranch: document.querySelector("#checkout-branch"),
  filesList: document.querySelector("#files-list"),
  statusList: document.querySelector("#status-list"),
  historyList: document.querySelector("#history-list"),
  branchList: document.querySelector("#branch-list"),
  relayUrl: document.querySelector("#relay-url"),
  relayEditorLabel: document.querySelector("#relay-editor-label"),
  relayAuthToken: document.querySelector("#relay-auth-token"),
  relayHost: document.querySelector("#relay-host"),
  relaySessionsRefresh: document.querySelector("#relay-sessions-refresh"),
  relayPull: document.querySelector("#relay-pull"),
  relaySessions: document.querySelector("#relay-sessions"),
  terminalOutput: document.querySelector("#terminal-output"),
  terminalForm: document.querySelector("#terminal-form"),
  terminalInput: document.querySelector("#terminal-input"),
  terminalHelp: document.querySelector("#terminal-help"),
  terminalStatus: document.querySelector("#terminal-status"),
  terminalLog: document.querySelector("#terminal-log"),
};

const terminalEntries = [];

const escapeHtml = (value) => String(value ?? "")
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll("\"", "&quot;");

const quoteArgument = (value) => `"${String(value ?? "").replaceAll("\\", "\\\\").replaceAll("\"", "\\\"")}"`;

const syncDraftFromInputs = () => {
  app.setEditorPath(elements.filePath.value);
  app.setEditorContent(elements.fileContent.value);
  app.setCommitMessage(elements.commitMessage.value);
  app.setBranchName(elements.branchName.value);
  app.setRelayDraft({
    remoteUrl: elements.relayUrl.value,
    editorLabel: elements.relayEditorLabel.value,
    authToken: elements.relayAuthToken.value,
  });
};

const pushTerminal = (lines, tone = "info") => {
  for (const line of Array.isArray(lines) ? lines : [lines]) {
    terminalEntries.push({
      id: crypto.randomUUID(),
      line: String(line),
      tone,
    });
  }
  while (terminalEntries.length > 96) {
    terminalEntries.shift();
  }
};

const renderTerminal = () => {
  elements.terminalOutput.innerHTML = terminalEntries.map((entry) => `
    <li class="terminal-line tone-${entry.tone}">
      <code>${escapeHtml(entry.line)}</code>
    </li>
  `).join("");
  const lastEntry = elements.terminalOutput.lastElementChild;
  if (lastEntry) {
    lastEntry.scrollIntoView({ block: "end" });
  }
};

const renderHeader = (snapshot) => {
  const status = snapshot.view.currentStatus;
  const staged = status.stagedAdded.length + status.stagedModified.length + status.stagedDeleted.length;
  const unstaged = status.unstagedModified.length + status.unstagedDeleted.length;
  const chips = [
    `profile ${snapshot.profile}`,
    `HEAD ${snapshot.currentBranch}`,
    `${staged} staged`,
    `${unstaged} unstaged`,
  ];
  if (snapshot.controller.lastSavedAt) {
    chips.push(`saved ${app.formatTimestamp(snapshot.controller.lastSavedAt)}`);
  }
  elements.heroMeta.innerHTML = chips.map((chip) => `<span class="meta-chip">${escapeHtml(chip)}</span>`).join("");
  elements.storageBanner.textContent = snapshot.storageBanner;
};

const renderFiles = (snapshot) => {
  const files = app.listFiles();
  if (files.length === 0) {
    elements.filesList.innerHTML = `<li class="empty-row">No files yet.</li>`;
    return;
  }
  elements.filesList.innerHTML = files.map((path) => `
    <li>
      <button
        class="list-button ${path === snapshot.editor.path ? "is-current" : ""}"
        type="button"
        data-open-path="${escapeHtml(path)}"
      >
        <code>${escapeHtml(path)}</code>
      </button>
    </li>
  `).join("");
};

const renderStatus = (snapshot) => {
  const groups = STATUS_GROUPS
    .map(([key, label]) => ({ label, items: snapshot.view.currentStatus[key] ?? [] }))
    .filter((group) => group.items.length > 0);
  if (groups.length === 0) {
    elements.statusList.innerHTML = `<li class="empty-row">Working tree clean.</li>`;
    return;
  }
  elements.statusList.innerHTML = groups.map((group) => `
    <li class="status-group">
      <strong>${escapeHtml(group.label)}</strong>
      <div class="status-items">
        ${group.items.map((item) => `
          <button class="mini-chip" type="button" data-open-path="${escapeHtml(item)}">
            <code>${escapeHtml(item)}</code>
          </button>
        `).join("")}
      </div>
    </li>
  `).join("");
};

const renderHistory = (snapshot) => {
  if (snapshot.view.logEntries.length === 0) {
    elements.historyList.innerHTML = `<li class="empty-row">No commits yet.</li>`;
    return;
  }
  elements.historyList.innerHTML = snapshot.view.logEntries.slice(0, 8).map((entry) => `
    <li class="history-item">
      <div class="history-meta">
        <code>${escapeHtml(entry.id.slice(0, 7))}</code>
        <span>${escapeHtml(new Date(entry.timestamp * 1000).toLocaleString())}</span>
      </div>
      <strong>${escapeHtml(entry.message)}</strong>
      <span>${escapeHtml(entry.author)}</span>
    </li>
  `).join("");
};

const renderBranches = (snapshot) => {
  if (snapshot.view.branches.length === 0) {
    elements.branchList.innerHTML = `<li class="empty-row">No branches yet.</li>`;
    return;
  }
  elements.branchList.innerHTML = snapshot.view.branches.map((branch) => `
    <li>
      <button
        class="list-button ${branch.isCurrent ? "is-current" : ""}"
        type="button"
        data-checkout-branch="${escapeHtml(branch.name)}"
      >
        <span>${branch.isCurrent ? "current" : "branch"}</span>
        <code>${escapeHtml(branch.name)}</code>
      </button>
    </li>
  `).join("");
};

const renderRelay = (snapshot) => {
  const relay = snapshot.relay;
  if (relay.sessions.length === 0) {
    elements.relaySessions.innerHTML = `<li class="empty-row">No hosted editors.</li>`;
    return;
  }
  elements.relaySessions.innerHTML = relay.sessions.map((session) => `
    <li>
      <button
        class="list-button ${session.sessionId === relay.selectedSessionId ? "is-current" : ""}"
        type="button"
        data-session-id="${escapeHtml(session.sessionId)}"
      >
        <span>${escapeHtml(session.label)}</span>
        <code>${escapeHtml(session.sessionId)}</code>
      </button>
    </li>
  `).join("");
};

const render = () => {
  const snapshot = app.snapshot();
  elements.filePath.value = snapshot.editor.path;
  elements.fileContent.value = snapshot.editor.content;
  elements.commitMessage.value = snapshot.commitMessage;
  elements.branchName.value = snapshot.branchName;
  elements.relayUrl.value = snapshot.relay.remoteUrl;
  elements.relayEditorLabel.value = snapshot.relay.editorLabel;
  elements.relayAuthToken.value = snapshot.relay.authToken;
  renderHeader(snapshot);
  renderFiles(snapshot);
  renderStatus(snapshot);
  renderHistory(snapshot);
  renderBranches(snapshot);
  renderRelay(snapshot);
  renderTerminal();
};

const executeCommand = async (command) => {
  const trimmed = String(command ?? "").trim();
  if (!trimmed) {
    return;
  }
  syncDraftFromInputs();
  pushTerminal([`$ ${trimmed}`], "prompt");
  const result = await runPlaygroundCommand(app, trimmed);
  pushTerminal(result.lines, result.ok ? "ok" : "error");
  render();
};

elements.filePath.addEventListener("input", () => {
  app.setEditorPath(elements.filePath.value);
});

elements.fileContent.addEventListener("input", () => {
  app.setEditorContent(elements.fileContent.value);
});

elements.fileContent.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "s") {
    event.preventDefault();
    void executeCommand("save");
  }
});

elements.commitMessage.addEventListener("input", () => {
  app.setCommitMessage(elements.commitMessage.value);
});

elements.branchName.addEventListener("input", () => {
  app.setBranchName(elements.branchName.value);
});

elements.relayUrl.addEventListener("input", () => {
  app.setRelayDraft({ remoteUrl: elements.relayUrl.value });
});

elements.relayEditorLabel.addEventListener("input", () => {
  app.setRelayDraft({ editorLabel: elements.relayEditorLabel.value });
});

elements.relayAuthToken.addEventListener("input", () => {
  app.setRelayDraft({ authToken: elements.relayAuthToken.value });
});

elements.openFile.addEventListener("click", () => {
  void executeCommand(`open ${quoteArgument(elements.filePath.value)}`);
});

elements.saveFile.addEventListener("click", () => {
  void executeCommand("save");
});

elements.stageFile.addEventListener("click", () => {
  void executeCommand(`add ${quoteArgument(elements.filePath.value)}`);
});

elements.commitFile.addEventListener("click", () => {
  void executeCommand(`commit ${quoteArgument(elements.commitMessage.value)}`);
});

elements.createBranch.addEventListener("click", () => {
  void executeCommand(`branch ${quoteArgument(elements.branchName.value)}`);
});

elements.checkoutBranch.addEventListener("click", () => {
  void executeCommand(`checkout ${quoteArgument(elements.branchName.value)}`);
});

elements.resetRepo.addEventListener("click", () => {
  void executeCommand("reset");
});

elements.relayHost.addEventListener("click", () => {
  const label = elements.relayEditorLabel.value.trim();
  void executeCommand(label ? `relay host ${quoteArgument(label)}` : "relay host");
});

elements.relaySessionsRefresh.addEventListener("click", () => {
  void executeCommand("relay sessions");
});

elements.relayPull.addEventListener("click", () => {
  void executeCommand("relay pull");
});

elements.filesList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-open-path]");
  if (!button) return;
  void executeCommand(`open ${quoteArgument(button.dataset.openPath)}`);
});

elements.statusList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-open-path]");
  if (!button) return;
  void executeCommand(`open ${quoteArgument(button.dataset.openPath)}`);
});

elements.branchList.addEventListener("click", (event) => {
  const button = event.target.closest("[data-checkout-branch]");
  if (!button) return;
  elements.branchName.value = button.dataset.checkoutBranch;
  app.setBranchName(button.dataset.checkoutBranch);
  void executeCommand(`checkout ${quoteArgument(button.dataset.checkoutBranch)}`);
});

elements.relaySessions.addEventListener("click", (event) => {
  const button = event.target.closest("[data-session-id]");
  if (!button) return;
  app.setRelayDraft({ selectedSessionId: button.dataset.sessionId });
  render();
  void executeCommand(`relay connect ${quoteArgument(button.dataset.sessionId)}`);
});

elements.terminalHelp.addEventListener("click", () => {
  void executeCommand("help");
});

elements.terminalStatus.addEventListener("click", () => {
  void executeCommand("status");
});

elements.terminalLog.addEventListener("click", () => {
  void executeCommand("log 5");
});

elements.terminalForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const command = elements.terminalInput.value;
  elements.terminalInput.value = "";
  void executeCommand(command);
});

globalThis.addEventListener("beforeunload", () => {
  app.destroy();
});

await app.hydrate();
pushTerminal([
  "bit playground ready",
  "IndexedDB-backed repo loaded. Type `help` or use the buttons above.",
], "info");
render();
