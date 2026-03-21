import {
  add,
  branchCreate,
  branchList,
  checkout,
  commit,
  init,
  log,
  status,
} from "../../tools/bit-git.mjs";
import {
  listHostedEditors,
  loadHostedEditorSnapshot,
  publishHostedSession,
  publishHostedSnapshot,
} from "./editor_link.js";
import { currentBranchName, readRelayDraftFromSearch, trimOptionalText } from "./relay_state.js";
import {
  DEFAULT_AUTHOR,
  DEFAULT_FILE_PATH,
  REPO_ROOT,
  STORAGE_PROFILE,
  absoluteFilePath,
  createIndexedDbController,
  summarizeWorkingSnapshot,
  timestampLabel,
} from "./storage.js";

const sampleReadme = `# bit browser demo

This repo is running fully in the browser.

- IndexedDB persistence
- backend-first host contract
- one-file edit loop
`;

const sampleNotes = `# Today

Edit this file, stage it, and commit again.
`;

const eventLog = [];
const controller = createIndexedDbController();
const relayDefaults = readRelayDraftFromSearch(globalThis.location?.search ?? "");
let relaySyncTimer = null;

const state = {
  filePath: DEFAULT_FILE_PATH,
  fileContent: sampleNotes,
  commitMessage: "demo: update notes",
  branchName: "feature/demo",
  selectedBranch: "main",
  relay: {
    remoteUrl: relayDefaults.remoteUrl,
    authToken: relayDefaults.authToken,
    editorLabel: relayDefaults.editorLabel || `editor-${STORAGE_PROFILE}`,
    sessions: [],
    hostedSession: null,
    hostedRevision: 0,
    hostedAt: null,
    selectedSessionId: relayDefaults.selectedSessionId,
    connectedSessionId: "",
    connectedRevision: 0,
    connectedLabel: "",
    lastPulledAt: null,
    busyAction: null,
  },
};

const elements = {
  consoleTitle: document.querySelector("#console-title"),
  consoleSubtitle: document.querySelector("#console-subtitle"),
  storageBanner: document.querySelector("#storage-banner"),
  resetRepo: document.querySelector("#reset-repo"),
  filePath: document.querySelector("#file-path"),
  fileContent: document.querySelector("#file-content"),
  loadFile: document.querySelector("#load-file"),
  saveFile: document.querySelector("#save-file"),
  stageFile: document.querySelector("#stage-file"),
  stageAll: document.querySelector("#stage-all"),
  commitMeta: document.querySelector("#commit-meta"),
  changeMapView: document.querySelector("#change-map-view"),
  commitMessage: document.querySelector("#commit-message"),
  branchName: document.querySelector("#branch-name"),
  commitFile: document.querySelector("#commit-file"),
  createBranch: document.querySelector("#create-branch"),
  checkoutBranch: document.querySelector("#checkout-branch"),
  branchStrip: document.querySelector("#branch-strip"),
  historyView: document.querySelector("#history-view"),
  relayUrl: document.querySelector("#relay-url"),
  relayEditorLabel: document.querySelector("#relay-editor-label"),
  relayAuthToken: document.querySelector("#relay-auth-token"),
  relayMeta: document.querySelector("#relay-meta"),
  relayDiscover: document.querySelector("#relay-discover"),
  relayFetch: document.querySelector("#relay-fetch"),
  relayPush: document.querySelector("#relay-push"),
  relayResults: document.querySelector("#relay-results"),
  snapshotView: document.querySelector("#snapshot-view"),
  eventLog: document.querySelector("#event-log"),
};

const trimRelativePath = (value) => value.replace(/^\/+/, "").trim();

const logEvent = (message, tone = "info") => {
  eventLog.unshift({
    id: crypto.randomUUID(),
    message,
    tone,
    at: new Date(),
  });
  eventLog.splice(24);
};

const stopRelaySyncLoop = () => {
  if (relaySyncTimer != null) {
    globalThis.clearInterval(relaySyncTimer);
    relaySyncTimer = null;
  }
};

const makeSessionId = () => crypto.randomUUID().replace(/-/g, "").slice(0, 8);

const relayLabel = () => trimOptionalText(state.relay.editorLabel) ?? `editor-${STORAGE_PROFILE}`;

const clearRelayActivity = () => {
  stopRelaySyncLoop();
  state.relay.sessions = [];
  state.relay.hostedSession = null;
  state.relay.hostedRevision = 0;
  state.relay.hostedAt = null;
  state.relay.selectedSessionId = "";
  state.relay.connectedSessionId = "";
  state.relay.connectedRevision = 0;
  state.relay.connectedLabel = "";
  state.relay.lastPulledAt = null;
};

const applyRemoteSnapshot = async (remoteSnapshot) => {
  controller.host.replaceSnapshot(remoteSnapshot.snapshot);
  if (remoteSnapshot.filePath) {
    state.filePath = remoteSnapshot.filePath;
  }
  if (!loadSnapshotIntoEditor()) {
    const summary = summarizeWorkingSnapshot(controller.host);
    const firstFile = summary.workingFiles[0];
    if (firstFile) {
      state.filePath = trimRelativePath(firstFile.replace(`${REPO_ROOT}/`, ""));
      loadSnapshotIntoEditor();
    }
  }
  await controller.persist();
  state.relay.connectedSessionId = remoteSnapshot.sessionId;
  state.relay.connectedLabel = remoteSnapshot.label;
  state.relay.connectedRevision = remoteSnapshot.revision;
  state.relay.lastPulledAt = new Date(remoteSnapshot.updatedAt || Date.now());
};

const publishCurrentSnapshot = async () => {
  const remoteUrl = trimOptionalText(state.relay.remoteUrl);
  if (!remoteUrl || !state.relay.hostedSession) {
    return false;
  }
  const nextRevision = state.relay.hostedRevision + 1;
  await publishHostedSnapshot(
    globalThis.fetch.bind(globalThis),
    remoteUrl,
    trimOptionalText(state.relay.authToken),
    state.relay.hostedSession,
    controller.host.exportSnapshot(),
    {
      revision: nextRevision,
      updatedAt: Date.now(),
      filePath: state.filePath,
    },
  );
  state.relay.hostedRevision = nextRevision;
  state.relay.hostedAt = new Date();
  return true;
};

const refreshHostedSessions = async () => {
  const remoteUrl = trimOptionalText(state.relay.remoteUrl);
  if (!remoteUrl) {
    throw new Error("Relay remote is required.");
  }
  state.relay.sessions = await listHostedEditors(
    globalThis.fetch.bind(globalThis),
    remoteUrl,
    trimOptionalText(state.relay.authToken),
  );
  if (!state.relay.selectedSessionId && state.relay.sessions[0]) {
    state.relay.selectedSessionId = state.relay.sessions[0].sessionId;
  }
  return state.relay.sessions;
};

const pullSelectedSession = async ({ silent = false } = {}) => {
  const remoteUrl = trimOptionalText(state.relay.remoteUrl);
  const sessionId = trimOptionalText(state.relay.selectedSessionId || state.relay.connectedSessionId);
  if (!remoteUrl || !sessionId) {
    if (silent) return false;
    throw new Error("Select a hosted editor first.");
  }
  const remoteSnapshot = await loadHostedEditorSnapshot(
    globalThis.fetch.bind(globalThis),
    remoteUrl,
    trimOptionalText(state.relay.authToken),
    sessionId,
  );
  if (!remoteSnapshot) {
    if (silent) return false;
    throw new Error(`No snapshot published for session ${sessionId}.`);
  }
  if (remoteSnapshot.revision <= state.relay.connectedRevision
    && state.relay.connectedSessionId === sessionId) {
    return false;
  }
  await applyRemoteSnapshot(remoteSnapshot);
  if (!silent) {
    logEvent(`Connected to ${remoteSnapshot.label} (${remoteSnapshot.sessionId})`, "info");
  }
  return true;
};

const startRelaySyncLoop = () => {
  stopRelaySyncLoop();
  if (!trimOptionalText(state.relay.remoteUrl) || !trimOptionalText(state.relay.connectedSessionId)) {
    return;
  }
  relaySyncTimer = globalThis.setInterval(() => {
    void pullSelectedSession({ silent: true }).then((updated) => {
      if (updated) {
        render();
      }
    }).catch((error) => {
      console.error(error);
    });
  }, 2000);
};

const collectStatusGroups = (currentStatus) => [
  ["Staged Added", currentStatus.stagedAdded],
  ["Staged Modified", currentStatus.stagedModified],
  ["Staged Deleted", currentStatus.stagedDeleted],
  ["Unstaged Modified", currentStatus.unstagedModified],
  ["Unstaged Deleted", currentStatus.unstagedDeleted],
  ["Untracked", currentStatus.untracked],
];

const summarizeStatus = (currentStatus) => ({
  staged: currentStatus.stagedAdded.length
    + currentStatus.stagedModified.length
    + currentStatus.stagedDeleted.length,
  unstaged: currentStatus.unstagedModified.length + currentStatus.unstagedDeleted.length,
  untracked: currentStatus.untracked.length,
});

const emptyStatus = () => ({
  stagedAdded: [],
  stagedModified: [],
  stagedDeleted: [],
  unstagedModified: [],
  unstagedDeleted: [],
  untracked: [],
});

const readView = () => {
  const summary = summarizeWorkingSnapshot(controller.host);
  const repoReady = controller.isRepoInitialized();
  if (!repoReady) {
    return {
      repoReady,
      summary,
      branches: [],
      logEntries: [],
      currentStatus: emptyStatus(),
    };
  }

  return {
    repoReady,
    summary,
    branches: branchList(controller.host, REPO_ROOT),
    logEntries: log(controller.host, REPO_ROOT, 8),
    currentStatus: status(controller.host, REPO_ROOT),
  };
};

const createSampleRepo = async () => {
  controller.host.reset();
  init(controller.host, REPO_ROOT, "main");
  controller.host.writeString(absoluteFilePath("README.md"), sampleReadme);
  controller.host.writeString(absoluteFilePath(DEFAULT_FILE_PATH), sampleNotes);
  add(controller.host, REPO_ROOT, ["README.md", DEFAULT_FILE_PATH]);
  commit(
    controller.host,
    REPO_ROOT,
    "demo: seed sample repo",
    DEFAULT_AUTHOR,
    Math.floor(Date.now() / 1000),
  );
  state.filePath = DEFAULT_FILE_PATH;
  state.fileContent = controller.host.readString(absoluteFilePath(DEFAULT_FILE_PATH));
  state.branchName = "feature/demo";
  state.selectedBranch = "main";
  clearRelayActivity();
};

const loadSnapshotIntoEditor = () => {
  const absolutePath = absoluteFilePath(state.filePath);
  if (!controller.host.isFile(absolutePath)) {
    return false;
  }
  state.fileContent = controller.host.readString(absolutePath);
  return true;
};

const focusFile = (relativePath) => {
  state.filePath = relativePath;
  if (!loadSnapshotIntoEditor()) {
    logEvent(`File ${state.filePath} is not present in this repo`, "error");
  }
  render();
};

const runOperation = async (
  label,
  operation,
  { persist = true, busyKey = null } = {},
) => {
  if (busyKey) {
    state.relay.busyAction = busyKey;
    render();
  }

  try {
    const result = await operation();
    if (persist) {
      await controller.persist();
      if (state.relay.hostedSession) {
        await publishCurrentSnapshot();
      }
    }
    logEvent(label, "info");
    return result;
  } catch (error) {
    console.error(error);
    logEvent(`${label}: ${error instanceof Error ? error.message : String(error)}`, "error");
    return null;
  } finally {
    if (busyKey) {
      state.relay.busyAction = null;
    }
    render();
  }
};

const renderCommitMeta = (view) => {
  const currentBranch = currentBranchName(view.branches, "main");
  const statusSummary = summarizeStatus(view.currentStatus);
  const chips = [
    `HEAD ${currentBranch}`,
    `${statusSummary.staged} staged`,
    `${statusSummary.unstaged} unstaged`,
    `${statusSummary.untracked} untracked`,
  ];
  if (controller.lastSavedAt) {
    chips.push(`saved ${timestampLabel(controller.lastSavedAt)}`);
  }
  elements.commitMeta.innerHTML = chips.map((value) => (
    `<span class="status-chip">${value}</span>`
  )).join("");
};

const renderChangeMap = (view) => {
  if (!view.repoReady) {
    elements.changeMapView.innerHTML = `
      <article class="status-group status-group-clean">
        <h4>Preparing sample repo</h4>
        <p class="status-empty">The default repo is being created in IndexedDB.</p>
      </article>
    `;
    return;
  }

  const currentPath = state.filePath;
  const currentGroups = collectStatusGroups(view.currentStatus)
    .filter(([, items]) => items.includes(currentPath))
    .map(([title]) => title);
  const nonEmptyGroups = collectStatusGroups(view.currentStatus)
    .filter(([, items]) => items.length > 0);

  const focusCard = `
    <article class="status-group focus-group">
      <h4>Editing now</h4>
      <p class="focus-path"><code>${currentPath}</code></p>
      <p class="status-empty">
        ${currentGroups.length
          ? `Current file appears in ${currentGroups.join(", ")}.`
          : "Current file has no staged or unstaged change yet."}
      </p>
    </article>
  `;

  const changeGroups = nonEmptyGroups.map(([title, items]) => `
    <article class="status-group">
      <h4>${title}</h4>
      <ul class="status-list">
        ${items.map((item) => `
          <li>
            <button
              class="change-link ${item === currentPath ? "current" : ""}"
              data-path="${item}"
              type="button"
            >
              <code>${item}</code>
            </button>
          </li>
        `).join("")}
      </ul>
    </article>
  `).join("");

  elements.changeMapView.innerHTML = focusCard + (changeGroups || `
    <article class="status-group status-group-clean">
      <h4>Working tree clean</h4>
      <p class="status-empty">Save or edit a file to create a visible change here.</p>
    </article>
  `);

  for (const button of elements.changeMapView.querySelectorAll("[data-path]")) {
    button.addEventListener("click", () => {
      focusFile(button.dataset.path);
    });
  }
};

const renderHistory = (view) => {
  if (!view.repoReady || view.logEntries.length === 0) {
    elements.historyView.innerHTML = `<p class="history-empty">No commits yet.</p>`;
    return;
  }

  elements.historyView.innerHTML = view.logEntries.slice(0, 6).map((entry) => `
    <article class="history-item">
      <header>
        <span>${entry.id.slice(0, 7)}</span>
        <span>${new Date(entry.timestamp * 1000).toLocaleString()}</span>
      </header>
      <strong>${entry.message}</strong>
      <div>${entry.author}</div>
    </article>
  `).join("");
};

const renderRelayPanel = (view) => {
  const remoteUrl = trimOptionalText(state.relay.remoteUrl);
  const chips = [
    `<span class="status-chip">profile ${STORAGE_PROFILE}</span>`,
    `<span class="status-chip">${remoteUrl ? "relay ready" : "relay url needed"}</span>`,
  ];

  if (state.relay.hostedSession) {
    chips.push(`<span class="status-chip">hosting ${state.relay.hostedSession.sessionId}</span>`);
  }
  if (state.relay.connectedSessionId) {
    chips.push(`<span class="status-chip">connected ${state.relay.connectedSessionId}</span>`);
  }
  if (state.relay.hostedAt) {
    chips.push(`<span class="status-chip">published ${timestampLabel(state.relay.hostedAt)}</span>`);
  }
  if (state.relay.lastPulledAt) {
    chips.push(`<span class="status-chip">pulled ${timestampLabel(state.relay.lastPulledAt)}</span>`);
  }

  elements.relayMeta.innerHTML = chips.join("");

  const introCard = remoteUrl
    ? `
      <article class="status-group">
        <h4>Relay endpoint</h4>
        <p class="focus-path"><code>${remoteUrl}</code></p>
        <p class="status-empty">
          Host mode publishes the current repo snapshot to relay after every save, stage, or commit.
          Connected editors pull the latest snapshot automatically.
        </p>
      </article>
    `
    : `
      <article class="status-group status-group-clean">
        <h4>Ready for editor link</h4>
        <p class="status-empty">
          Enter a relay like <code>relay+https://relay.example.com/base?room=playground</code>,
          start hosting in one tab, then connect from another tab with a different <code>?profile=...</code>.
        </p>
      </article>
    `;

  const hostedCard = state.relay.hostedSession
    ? (() => {
      const shareUrl = new URL(globalThis.location.href);
      shareUrl.searchParams.set("relay", remoteUrl ?? "");
      shareUrl.searchParams.set("session", state.relay.hostedSession.sessionId);
      shareUrl.searchParams.set("profile", "client");
      return `
        <article class="status-group">
          <h4>Hosting now</h4>
          <p class="status-empty">
            <strong>${state.relay.hostedSession.label}</strong> is publishing revision ${state.relay.hostedRevision}.
          </p>
          <ul class="status-list">
            <li>session: <code>${state.relay.hostedSession.sessionId}</code></li>
            <li>share url: <code>${shareUrl.toString()}</code></li>
          </ul>
        </article>
      `;
    })()
    : `
      <article class="status-group status-group-clean">
        <h4>Host this editor</h4>
        <p class="status-empty">
          Starting host mode shares the full repo snapshot, including <code>.git</code>, through relay.
        </p>
      </article>
    `;

  const connectedCard = state.relay.connectedSessionId
    ? `
      <article class="status-group">
        <h4>Connected editor</h4>
        <p class="status-empty">
          Following <strong>${state.relay.connectedLabel || state.relay.connectedSessionId}</strong>
          at revision ${state.relay.connectedRevision}.
        </p>
        <ul class="status-list">
          <li>session: <code>${state.relay.connectedSessionId}</code></li>
          <li>last pull: ${timestampLabel(state.relay.lastPulledAt)}</li>
        </ul>
      </article>
    `
    : "";

  const sessionsCard = state.relay.sessions.length > 0
    ? `
      <article class="status-group">
        <h4>Hosted editors</h4>
        <ul class="relay-peer-list">
          ${state.relay.sessions.map((session) => `
            <li>
              <button
                class="relay-peer ${session.sessionId === state.relay.selectedSessionId ? "current" : ""}"
                type="button"
                data-session-id="${session.sessionId}"
                aria-pressed="${session.sessionId === state.relay.selectedSessionId}"
              >
                <strong>${session.label}</strong>
                <span>${session.sender}</span>
                <code>${session.sessionId}</code>
              </button>
            </li>
          `).join("")}
        </ul>
      </article>
    `
    : remoteUrl
      ? `
        <article class="status-group status-group-clean">
          <h4>Hosted editors</h4>
          <p class="status-empty">
            Nothing announced yet. Start host mode in another tab, then click <strong>Refresh hosted editors</strong>.
          </p>
        </article>
      `
      : "";

  elements.relayResults.innerHTML = [
    introCard,
    hostedCard,
    connectedCard,
    sessionsCard,
  ].join("");

  for (const button of elements.relayResults.querySelectorAll("[data-session-id]")) {
    button.addEventListener("click", () => {
      state.relay.selectedSessionId = button.dataset.sessionId ?? "";
      render();
    });
  }
};

const renderSnapshot = (view) => {
  const summary = view.summary;
  const workingFiles = summary.workingFiles.length
    ? `<ul>${summary.workingFiles.map((path) => {
      const relative = trimRelativePath(path.replace(`${REPO_ROOT}/`, ""));
      return `
        <li>
          <button class="snapshot-chip" data-path="${relative}" type="button">${relative}</button>
        </li>
      `;
    }).join("")}</ul>`
    : `<p class="snapshot-empty">No working tree files yet.</p>`;

  elements.snapshotView.innerHTML = `
    <article class="snapshot-item">
      <h4>Persistence footprint</h4>
      <div class="storage-meta-row">
        <span class="snapshot-chip">${summary.fileCount} files</span>
        <span class="snapshot-chip">${summary.dirCount} directories</span>
        <span class="snapshot-chip">${summary.gitObjectCount} git objects</span>
      </div>
    </article>
    <article class="snapshot-item">
      <h4>Working tree files</h4>
      ${workingFiles}
    </article>
    <article class="snapshot-item">
      <h4>Persistence status</h4>
      <ul>
        <li>last load: ${timestampLabel(controller.lastLoadedAt)}</li>
        <li>last save: ${timestampLabel(controller.lastSavedAt)}</li>
        <li>mode: IndexedDB</li>
      </ul>
    </article>
  `;

  for (const button of elements.snapshotView.querySelectorAll("[data-path]")) {
    button.addEventListener("click", () => {
      focusFile(button.dataset.path);
    });
  }
};

const renderEventLog = () => {
  elements.eventLog.innerHTML = eventLog.slice(0, 8).map((entry) => `
    <li>
      <strong>${entry.at.toLocaleTimeString()}</strong>
      <div>${entry.message}</div>
    </li>
  `).join("");
};

const renderBranchStrip = (view) => {
  if (!view.repoReady) {
    elements.branchStrip.innerHTML = `<span class="branch-chip">main</span>`;
    return;
  }

  const current = view.branches.find((branch) => branch.isCurrent);
  if (current) {
    state.selectedBranch = current.name;
  }

  elements.branchStrip.innerHTML = view.branches.map((branch) => `
    <button
      class="branch-chip"
      type="button"
      data-branch="${branch.name}"
      aria-pressed="${branch.name === state.selectedBranch}"
    >
      ${branch.name}${branch.isCurrent ? " · current" : ""}
    </button>
  `).join("");

  for (const button of elements.branchStrip.querySelectorAll("[data-branch]")) {
    button.addEventListener("click", () => {
      state.selectedBranch = button.dataset.branch;
      state.branchName = button.dataset.branch;
      render();
    });
  }
};

const render = () => {
  const view = readView();
  const repoReady = view.repoReady;
  const relayRemoteConfigured = Boolean(trimOptionalText(state.relay.remoteUrl));
  const relayBusy = Boolean(state.relay.busyAction);

  elements.consoleTitle.textContent = `IndexedDB demo / ${STORAGE_PROFILE}`;
  elements.consoleSubtitle.textContent = "Use one tab as host and another as client. Repo snapshots move through relay.";
  elements.filePath.value = state.filePath;
  elements.fileContent.value = state.fileContent;
  elements.commitMessage.value = state.commitMessage;
  elements.branchName.value = state.branchName;
  elements.relayUrl.value = state.relay.remoteUrl;
  elements.relayEditorLabel.value = state.relay.editorLabel;
  elements.relayAuthToken.value = state.relay.authToken;
  elements.relayDiscover.textContent = "Refresh hosted editors";
  elements.relayFetch.textContent = state.relay.connectedSessionId ? "Pull latest snapshot" : "Connect selected";
  elements.relayPush.textContent = state.relay.hostedSession ? "Re-publish this editor" : "Host this editor";

  renderCommitMeta(view);
  renderChangeMap(view);
  renderHistory(view);
  renderRelayPanel(view);
  renderSnapshot(view);
  renderBranchStrip(view);
  renderEventLog();

  elements.loadFile.disabled = !repoReady;
  elements.saveFile.disabled = !repoReady;
  elements.stageFile.disabled = !repoReady;
  elements.stageAll.disabled = !repoReady;
  elements.commitFile.disabled = !repoReady;
  elements.createBranch.disabled = !repoReady;
  elements.checkoutBranch.disabled = !repoReady;
  elements.relayDiscover.disabled = !repoReady || !relayRemoteConfigured || relayBusy;
  elements.relayFetch.disabled = !repoReady
    || !relayRemoteConfigured
    || relayBusy
    || !trimOptionalText(state.relay.selectedSessionId || state.relay.connectedSessionId);
  elements.relayPush.disabled = !repoReady || !relayRemoteConfigured || relayBusy;

  elements.storageBanner.innerHTML = `
    <span class="status-chip">IndexedDB persistence</span>
    <span class="status-chip">profile ${STORAGE_PROFILE}</span>
    <span class="status-chip">current file ${state.filePath}</span>
    <span class="status-chip">saved ${timestampLabel(controller.lastSavedAt)}</span>
  `;
};

elements.resetRepo.addEventListener("click", async () => {
  await runOperation("Reset sample repo", async () => {
    await controller.clear();
    await createSampleRepo();
  });
});

elements.loadFile.addEventListener("click", () => {
  if (loadSnapshotIntoEditor()) {
    logEvent(`Loaded ${state.filePath}`, "info");
  } else {
    state.fileContent = "";
    logEvent(`No file at ${state.filePath}`, "error");
  }
  render();
});

elements.saveFile.addEventListener("click", async () => {
  await runOperation(`Saved ${state.filePath}`, async () => {
    controller.host.writeString(absoluteFilePath(state.filePath), state.fileContent);
  });
});

elements.stageFile.addEventListener("click", async () => {
  await runOperation(`Staged ${state.filePath}`, async () => {
    add(controller.host, REPO_ROOT, [state.filePath]);
  });
});

elements.stageAll.addEventListener("click", async () => {
  await runOperation("Staged all working tree changes", async () => {
    add(controller.host, REPO_ROOT, ["."]);
  });
});

elements.commitFile.addEventListener("click", async () => {
  await runOperation(`Committed ${state.commitMessage}`, async () => {
    commit(
      controller.host,
      REPO_ROOT,
      state.commitMessage,
      DEFAULT_AUTHOR,
      Math.floor(Date.now() / 1000),
    );
  });
});

elements.createBranch.addEventListener("click", async () => {
  await runOperation(`Created branch ${state.branchName}`, async () => {
    branchCreate(controller.host, REPO_ROOT, state.branchName);
    state.selectedBranch = state.branchName;
  });
});

elements.checkoutBranch.addEventListener("click", async () => {
  await runOperation(`Checked out ${state.branchName}`, async () => {
    checkout(controller.host, REPO_ROOT, state.branchName);
    state.selectedBranch = state.branchName;
  });
});

elements.relayDiscover.addEventListener("click", async () => {
  await runOperation("Refreshed hosted editors", async () => {
    await refreshHostedSessions();
  }, { persist: false, busyKey: "discover" });
});

elements.relayFetch.addEventListener("click", async () => {
  await runOperation("Pulled latest hosted snapshot", async () => {
    await pullSelectedSession();
    startRelaySyncLoop();
  }, { busyKey: "fetch", persist: false });
});

elements.relayPush.addEventListener("click", async () => {
  await runOperation("Published this editor to relay", async () => {
    const remoteUrl = trimOptionalText(state.relay.remoteUrl);
    if (!remoteUrl) {
      throw new Error("Relay remote is required.");
    }
    if (!state.relay.hostedSession) {
      const hostedSession = {
        sessionId: makeSessionId(),
        label: relayLabel(),
        sender: relayLabel(),
        startedAt: Date.now(),
      };
      await publishHostedSession(
        globalThis.fetch.bind(globalThis),
        remoteUrl,
        trimOptionalText(state.relay.authToken),
        hostedSession,
      );
      state.relay.hostedSession = hostedSession;
      state.relay.hostedRevision = 0;
      state.relay.hostedAt = null;
      state.relay.selectedSessionId = hostedSession.sessionId;
    } else {
      state.relay.hostedSession.label = relayLabel();
      state.relay.hostedSession.sender = relayLabel();
      await publishHostedSession(
        globalThis.fetch.bind(globalThis),
        remoteUrl,
        trimOptionalText(state.relay.authToken),
        state.relay.hostedSession,
      );
    }
    await publishCurrentSnapshot();
    await refreshHostedSessions();
  }, { busyKey: "push", persist: false });
});

elements.filePath.addEventListener("input", (event) => {
  state.filePath = trimRelativePath(event.target.value || DEFAULT_FILE_PATH);
});

elements.fileContent.addEventListener("input", (event) => {
  state.fileContent = event.target.value;
});

elements.commitMessage.addEventListener("input", (event) => {
  state.commitMessage = event.target.value;
});

elements.branchName.addEventListener("input", (event) => {
  state.branchName = trimRelativePath(event.target.value || "feature/demo");
});

elements.relayUrl.addEventListener("input", (event) => {
  state.relay.remoteUrl = event.target.value;
  clearRelayActivity();
  render();
});

elements.relayEditorLabel.addEventListener("input", (event) => {
  state.relay.editorLabel = event.target.value;
  render();
});

elements.relayAuthToken.addEventListener("input", (event) => {
  state.relay.authToken = event.target.value;
  render();
});

const boot = async () => {
  try {
    await controller.hydrate();
  } catch (error) {
    console.error(error);
    logEvent(`Failed to load IndexedDB state: ${error.message}`, "error");
  }

  if (!controller.isRepoInitialized()) {
    try {
      await createSampleRepo();
      await controller.persist();
      logEvent("Created sample repo", "info");
    } catch (error) {
      console.error(error);
      logEvent(`Failed to create sample repo: ${error.message}`, "error");
    }
  }

  const summary = summarizeWorkingSnapshot(controller.host);
  if (!controller.host.isFile(absoluteFilePath(state.filePath)) && summary.workingFiles.length > 0) {
    state.filePath = trimRelativePath(summary.workingFiles[0].replace(`${REPO_ROOT}/`, ""));
  }
  if (!loadSnapshotIntoEditor()) {
    state.fileContent = sampleNotes;
  }

  if (trimOptionalText(state.relay.remoteUrl)) {
    try {
      await refreshHostedSessions();
      if (trimOptionalText(state.relay.selectedSessionId)) {
        await pullSelectedSession({ silent: true });
        startRelaySyncLoop();
      }
    } catch (error) {
      console.error(error);
      logEvent(`Relay setup skipped: ${error.message}`, "error");
    }
  }

  render();
  logEvent("Demo ready", "info");
  render();
};

void boot();
