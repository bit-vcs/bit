export const STATUS_GROUPS = [
  ["stagedAdded", "Staged Added"],
  ["stagedModified", "Staged Modified"],
  ["stagedDeleted", "Staged Deleted"],
  ["unstagedModified", "Unstaged Modified"],
  ["unstagedDeleted", "Unstaged Deleted"],
  ["untracked", "Untracked"],
];

export const escapeHtml = (value) => String(value ?? "")
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll("\"", "&quot;");

export const quoteArgument = (value) => `"${String(value ?? "")
  .replaceAll("\\", "\\\\")
  .replaceAll("\"", "\\\"")}"`;

const emptyRow = (label) => `<li class="empty-row">${escapeHtml(label)}</li>`;

export const renderHeroMetaHtml = (snapshot, formatTimestamp) => {
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
    chips.push(`saved ${formatTimestamp(snapshot.controller.lastSavedAt)}`);
  }
  return chips.map((chip) => `<span class="meta-chip">${escapeHtml(chip)}</span>`).join("");
};

export const renderFilesListHtml = (files, currentPath) => {
  if (files.length === 0) {
    return emptyRow("No files yet.");
  }
  return files.map((path) => `
    <li>
      <button
        class="list-button ${path === currentPath ? "is-current" : ""}"
        type="button"
        data-open-path="${escapeHtml(path)}"
      >
        <code>${escapeHtml(path)}</code>
      </button>
    </li>
  `).join("");
};

export const renderStatusListHtml = (status, groups = STATUS_GROUPS) => {
  const visibleGroups = groups
    .map(([key, label]) => ({ label, items: status?.[key] ?? [] }))
    .filter((group) => group.items.length > 0);
  if (visibleGroups.length === 0) {
    return emptyRow("Working tree clean.");
  }
  return visibleGroups.map((group) => `
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

export const renderHistoryListHtml = (entries) => {
  if (entries.length === 0) {
    return emptyRow("No commits yet.");
  }
  return entries.slice(0, 8).map((entry) => `
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

export const renderBranchListHtml = (branches) => {
  if (branches.length === 0) {
    return emptyRow("No branches yet.");
  }
  return branches.map((branch) => `
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

export const renderRelaySessionsHtml = (relay) => {
  if (relay.sessions.length === 0) {
    return emptyRow("No hosted editors.");
  }
  return relay.sessions.map((session) => `
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

export const renderTerminalHtml = (entries) => entries.map((entry) => `
  <li class="terminal-line tone-${entry.tone}">
    <code>${escapeHtml(entry.line)}</code>
  </li>
`).join("");

export const createTerminalBuffer = (limit = 96) => {
  let nextId = 1;
  const entries = [];

  return {
    push(lines, tone = "info") {
      for (const line of Array.isArray(lines) ? lines : [lines]) {
        entries.push({
          id: `term-${nextId}`,
          line: String(line),
          tone,
        });
        nextId += 1;
      }
      while (entries.length > limit) {
        entries.shift();
      }
    },
    snapshot() {
      return entries.map((entry) => ({ ...entry }));
    },
    renderHtml() {
      return renderTerminalHtml(entries);
    },
  };
};
