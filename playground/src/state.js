import {
  add,
  branchCreate,
  branchList,
  checkout,
  commit,
  init,
  log,
  readString,
  status,
  writeString,
} from "./bit.js";
import {
  listHostedEditors,
  loadHostedEditorSnapshot,
  publishHostedSession,
  publishHostedSnapshot,
} from "../../docs/demo/editor_link.js";
import { readRelayDraftFromSearch, trimOptionalText } from "../../docs/demo/relay_state.js";
import {
  DEFAULT_AUTHOR,
  DEFAULT_FILE_PATH,
  REPO_ROOT,
  STORAGE_PROFILE,
  absoluteFilePath,
  createIndexedDbController,
  summarizeWorkingSnapshot,
  timestampLabel,
} from "../../docs/demo/storage.js";

const sampleReadme = `# bit playground

This repo runs fully in the browser.

- IndexedDB persistence
- bit JS API
- optional relay sync
`;

const sampleNotes = `# Today

Edit this file, save it, stage it, and commit from the terminal.
`;

const emptyStatus = () => ({
  stagedAdded: [],
  stagedModified: [],
  stagedDeleted: [],
  unstagedModified: [],
  unstagedDeleted: [],
  untracked: [],
});

const trimRelativePath = (value) => String(value ?? "").replace(/^\/+/, "").trim();

const sortStrings = (left, right) => left.localeCompare(right);

const makeSessionId = () => crypto.randomUUID().replace(/-/g, "").slice(0, 8);

const nowTimestampSec = () => Math.floor(Date.now() / 1000);

const firstWorkingFile = (summary) => {
  const absolute = summary.workingFiles[0];
  if (!absolute) return DEFAULT_FILE_PATH;
  return trimRelativePath(absolute.replace(`${REPO_ROOT}/`, ""));
};

const cloneRelaySessions = (sessions) => sessions.map((session) => ({ ...session }));

export const STATUS_GROUPS = [
  ["stagedAdded", "Staged Added"],
  ["stagedModified", "Staged Modified"],
  ["stagedDeleted", "Staged Deleted"],
  ["unstagedModified", "Unstaged Modified"],
  ["unstagedDeleted", "Unstaged Deleted"],
  ["untracked", "Untracked"],
];

export const createPlaygroundApp = ({
  controller = createIndexedDbController(),
  fetchImpl = globalThis.fetch?.bind(globalThis),
  locationSearch = globalThis.location?.search ?? "",
} = {}) => {
  if (typeof fetchImpl !== "function") {
    throw new Error("Playground requires fetch for relay sync.");
  }

  const relayDefaults = readRelayDraftFromSearch(locationSearch);
  let relaySyncTimer = null;

  const state = {
    editor: {
      path: DEFAULT_FILE_PATH,
      content: sampleNotes,
    },
    commitMessage: "demo: update notes",
    branchName: "feature/demo",
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
    },
  };

  const stopRelaySyncLoop = () => {
    if (relaySyncTimer != null) {
      globalThis.clearInterval(relaySyncTimer);
      relaySyncTimer = null;
    }
  };

  const clearRelayState = () => {
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

  const getEditorPath = () => trimRelativePath(state.editor.path) || DEFAULT_FILE_PATH;

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
      logEntries: log(controller.host, REPO_ROOT, 12),
      currentStatus: status(controller.host, REPO_ROOT),
    };
  };

  const loadEditorFromHost = (relativePath) => {
    const normalized = trimRelativePath(relativePath) || DEFAULT_FILE_PATH;
    const absolutePath = absoluteFilePath(normalized);
    state.editor.path = normalized;
    state.editor.content = controller.host.isFile(absolutePath)
      ? readString(controller.host, absolutePath)
      : "";
    return { ...state.editor };
  };

  const publishCurrentSnapshot = async () => {
    const remoteUrl = trimOptionalText(state.relay.remoteUrl);
    if (!remoteUrl || !state.relay.hostedSession) {
      return false;
    }
    const revision = state.relay.hostedRevision + 1;
    await publishHostedSnapshot(
      fetchImpl,
      remoteUrl,
      trimOptionalText(state.relay.authToken),
      state.relay.hostedSession,
      controller.host.exportSnapshot(),
      {
        revision,
        updatedAt: Date.now(),
        filePath: getEditorPath(),
      },
    );
    state.relay.hostedRevision = revision;
    state.relay.hostedAt = new Date();
    return true;
  };

  const persistAfterMutation = async () => {
    await controller.persist();
    if (state.relay.hostedSession) {
      await publishCurrentSnapshot();
    }
  };

  const applyRemoteSnapshot = async (remoteSnapshot) => {
    controller.host.replaceSnapshot(remoteSnapshot.snapshot);
    const summary = summarizeWorkingSnapshot(controller.host);
    const nextPath = trimOptionalText(remoteSnapshot.filePath) ?? firstWorkingFile(summary);
    loadEditorFromHost(nextPath);
    await controller.persist();
    state.relay.connectedSessionId = remoteSnapshot.sessionId;
    state.relay.connectedLabel = remoteSnapshot.label;
    state.relay.connectedRevision = remoteSnapshot.revision;
    state.relay.lastPulledAt = new Date(remoteSnapshot.updatedAt || Date.now());
  };

  const pullConnectedSession = async ({ silent = false } = {}) => {
    const remoteUrl = trimOptionalText(state.relay.remoteUrl);
    const sessionId = trimOptionalText(state.relay.selectedSessionId || state.relay.connectedSessionId);
    if (!remoteUrl || !sessionId) {
      if (silent) return false;
      throw new Error("Relay remote and session are required.");
    }
    const remoteSnapshot = await loadHostedEditorSnapshot(
      fetchImpl,
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
    return true;
  };

  const startRelaySyncLoop = () => {
    stopRelaySyncLoop();
    if (!trimOptionalText(state.relay.remoteUrl) || !trimOptionalText(state.relay.connectedSessionId)) {
      return;
    }
    relaySyncTimer = globalThis.setInterval(() => {
      void pullConnectedSession({ silent: true }).catch((error) => {
        console.error(error);
      });
    }, 2000);
  };

  const createSampleRepo = async () => {
    controller.host.reset();
    init(controller.host, REPO_ROOT, "main");
    writeString(controller.host, absoluteFilePath("README.md"), sampleReadme);
    writeString(controller.host, absoluteFilePath(DEFAULT_FILE_PATH), sampleNotes);
    add(controller.host, REPO_ROOT, ["README.md", DEFAULT_FILE_PATH]);
    commit(
      controller.host,
      REPO_ROOT,
      "demo: seed sample repo",
      DEFAULT_AUTHOR,
      nowTimestampSec(),
    );
    loadEditorFromHost(DEFAULT_FILE_PATH);
    state.commitMessage = "demo: update notes";
    state.branchName = "feature/demo";
    clearRelayState();
    await controller.persist();
  };

  return {
    async hydrate() {
      await controller.hydrate();
      if (!controller.isRepoInitialized()) {
        await createSampleRepo();
      } else {
        const summary = summarizeWorkingSnapshot(controller.host);
        loadEditorFromHost(firstWorkingFile(summary));
      }
      return this.snapshot();
    },
    snapshot() {
      const view = readView();
      const currentBranch = view.branches.find((branch) => branch.isCurrent)?.name ?? "main";
      return {
        profile: STORAGE_PROFILE,
        storageBanner: controller.getBanner(),
        controller: {
          kind: controller.kind,
          lastSavedAt: controller.lastSavedAt,
          lastLoadedAt: controller.lastLoadedAt,
        },
        view,
        editor: { ...state.editor },
        commitMessage: state.commitMessage,
        branchName: state.branchName,
        currentBranch,
        relay: {
          ...state.relay,
          sessions: cloneRelaySessions(state.relay.sessions),
        },
      };
    },
    getView() {
      return readView();
    },
    getEditor() {
      return { ...state.editor };
    },
    getRelayState() {
      return {
        ...state.relay,
        sessions: cloneRelaySessions(state.relay.sessions),
      };
    },
    listFiles() {
      const summary = summarizeWorkingSnapshot(controller.host);
      return summary.workingFiles
        .map((path) => trimRelativePath(path.replace(`${REPO_ROOT}/`, "")))
        .sort(sortStrings);
    },
    setEditorPath(path) {
      state.editor.path = trimRelativePath(path) || DEFAULT_FILE_PATH;
      return this.getEditor();
    },
    setEditorContent(content) {
      state.editor.content = String(content ?? "");
      return this.getEditor();
    },
    setCommitMessage(message) {
      state.commitMessage = String(message ?? "");
      return state.commitMessage;
    },
    setBranchName(name) {
      state.branchName = String(name ?? "");
      return state.branchName;
    },
    setRelayDraft(nextDraft = {}) {
      state.relay.remoteUrl = "remoteUrl" in nextDraft ? String(nextDraft.remoteUrl ?? "") : state.relay.remoteUrl;
      state.relay.authToken = "authToken" in nextDraft ? String(nextDraft.authToken ?? "") : state.relay.authToken;
      state.relay.editorLabel = "editorLabel" in nextDraft
        ? String(nextDraft.editorLabel ?? "")
        : state.relay.editorLabel;
      state.relay.selectedSessionId = "selectedSessionId" in nextDraft
        ? String(nextDraft.selectedSessionId ?? "")
        : state.relay.selectedSessionId;
      return this.getRelayState();
    },
    async openFile(relativePath) {
      return loadEditorFromHost(relativePath);
    },
    async saveEditor() {
      writeString(controller.host, absoluteFilePath(getEditorPath()), state.editor.content);
      await persistAfterMutation();
      return this.getEditor();
    },
    async stagePaths(paths) {
      const normalized = Array.from(paths ?? [])
        .map((path) => trimRelativePath(path))
        .filter(Boolean);
      add(controller.host, REPO_ROOT, normalized.length > 0 ? normalized : [getEditorPath()]);
      await persistAfterMutation();
      return readView().currentStatus;
    },
    async commit(message) {
      const normalized = String(message ?? state.commitMessage).trim();
      if (!normalized) {
        throw new Error("commit requires a message");
      }
      state.commitMessage = normalized;
      const commitId = commit(
        controller.host,
        REPO_ROOT,
        normalized,
        DEFAULT_AUTHOR,
        nowTimestampSec(),
      );
      await persistAfterMutation();
      return commitId;
    },
    listHistory(count = 8) {
      return log(controller.host, REPO_ROOT, count);
    },
    listBranches() {
      return branchList(controller.host, REPO_ROOT);
    },
    async createBranch(name) {
      branchCreate(controller.host, REPO_ROOT, String(name).trim());
      await persistAfterMutation();
    },
    async checkoutBranch(name) {
      checkout(controller.host, REPO_ROOT, String(name).trim());
      await persistAfterMutation();
      loadEditorFromHost(getEditorPath());
    },
    async startHosting(label = null) {
      const remoteUrl = trimOptionalText(state.relay.remoteUrl);
      if (!remoteUrl) {
        throw new Error("Relay remote is required.");
      }
      const session = {
        sessionId: makeSessionId(),
        label: trimOptionalText(label) ?? trimOptionalText(state.relay.editorLabel) ?? `editor-${STORAGE_PROFILE}`,
        sender: trimOptionalText(state.relay.editorLabel) ?? `editor-${STORAGE_PROFILE}`,
        startedAt: Date.now(),
      };
      await publishHostedSession(
        fetchImpl,
        remoteUrl,
        trimOptionalText(state.relay.authToken),
        session,
      );
      state.relay.hostedSession = session;
      state.relay.hostedRevision = 0;
      await publishCurrentSnapshot();
      return session;
    },
    async refreshSessions() {
      const remoteUrl = trimOptionalText(state.relay.remoteUrl);
      if (!remoteUrl) {
        throw new Error("Relay remote is required.");
      }
      state.relay.sessions = await listHostedEditors(
        fetchImpl,
        remoteUrl,
        trimOptionalText(state.relay.authToken),
      );
      if (!state.relay.selectedSessionId && state.relay.sessions[0]) {
        state.relay.selectedSessionId = state.relay.sessions[0].sessionId;
      }
      return cloneRelaySessions(state.relay.sessions);
    },
    async connectSession(sessionId) {
      state.relay.selectedSessionId = String(sessionId ?? "").trim();
      const updated = await pullConnectedSession();
      if (updated) {
        startRelaySyncLoop();
      }
      return updated;
    },
    async pullConnectedSession() {
      return pullConnectedSession();
    },
    async resetSampleRepo() {
      await createSampleRepo();
      return this.snapshot();
    },
    formatTimestamp(value) {
      return timestampLabel(value);
    },
    destroy() {
      stopRelaySyncLoop();
    },
  };
};
