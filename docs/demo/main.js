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
  DEFAULT_AUTHOR,
  DEFAULT_FILE_PATH,
  REPO_ROOT,
  absoluteFilePath,
  createStorageControllers,
  summarizeWorkingSnapshot,
  timestampLabel,
} from "./storage.js";

const sampleReadme = `# bit browser demo

This repo is running fully in the browser.

- same Git core
- different persistence strategy
- backend-first host contract
`;

const sampleNotes = `# Today

Switch between storage modes, edit this file, stage it, and commit again.
`;

const eventLog = [];
const storageControllers = createStorageControllers();
const state = {
  activeStorageId: storageControllers[0].id,
  filePath: DEFAULT_FILE_PATH,
  fileContent: sampleNotes,
  commitMessage: "demo: update notes",
  branchName: "feature/demo",
  selectedBranch: "main",
};

const elements = {
  storageCards: document.querySelector("#storage-cards"),
  consoleTitle: document.querySelector("#console-title"),
  consoleSubtitle: document.querySelector("#console-subtitle"),
  storageBanner: document.querySelector("#storage-banner"),
  connectStorage: document.querySelector("#connect-storage"),
  reloadStorage: document.querySelector("#reload-storage"),
  clearStorage: document.querySelector("#clear-storage"),
  seedRepo: document.querySelector("#seed-repo"),
  filePath: document.querySelector("#file-path"),
  fileContent: document.querySelector("#file-content"),
  loadFile: document.querySelector("#load-file"),
  saveFile: document.querySelector("#save-file"),
  stageFile: document.querySelector("#stage-file"),
  stageAll: document.querySelector("#stage-all"),
  commitMessage: document.querySelector("#commit-message"),
  branchName: document.querySelector("#branch-name"),
  commitFile: document.querySelector("#commit-file"),
  createBranch: document.querySelector("#create-branch"),
  checkoutBranch: document.querySelector("#checkout-branch"),
  branchStrip: document.querySelector("#branch-strip"),
  statusView: document.querySelector("#status-view"),
  historyView: document.querySelector("#history-view"),
  snapshotView: document.querySelector("#snapshot-view"),
  eventLog: document.querySelector("#event-log"),
};

const getActiveController = () => (
  storageControllers.find((controller) => controller.id === state.activeStorageId)
);

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

const runMutation = async (label, operation) => {
  const controller = getActiveController();
  try {
    const result = await operation(controller);
    if (controller.id !== "memory") {
      await controller.persist();
    }
    logEvent(label, "info");
    render(result);
  } catch (error) {
    console.error(error);
    logEvent(`${label}: ${error instanceof Error ? error.message : String(error)}`, "error");
    render();
  }
};

const loadSnapshotIntoEditor = () => {
  const controller = getActiveController();
  const absolutePath = absoluteFilePath(state.filePath);
  if (!controller.host.isFile(absolutePath)) {
    return false;
  }
  state.fileContent = controller.host.readString(absolutePath);
  return true;
};

const collectStatusGroups = (currentStatus) => {
  return [
    ["Untracked", currentStatus.untracked],
    ["Staged Added", currentStatus.stagedAdded],
    ["Staged Modified", currentStatus.stagedModified],
    ["Staged Deleted", currentStatus.stagedDeleted],
    ["Unstaged Modified", currentStatus.unstagedModified],
    ["Unstaged Deleted", currentStatus.unstagedDeleted],
  ];
};

const summarizeStatus = (currentStatus) => ({
  staged: currentStatus.stagedAdded.length
    + currentStatus.stagedModified.length
    + currentStatus.stagedDeleted.length,
  unstaged: currentStatus.unstagedModified.length + currentStatus.unstagedDeleted.length,
  untracked: currentStatus.untracked.length,
});

const readControllerView = (controller) => {
  const summary = summarizeWorkingSnapshot(controller.host);
  const repoReady = controller.isRepoInitialized();
  if (!repoReady) {
    return {
      repoReady,
      summary,
      branches: [],
      logEntries: [],
      currentStatus: {
        stagedAdded: [],
        stagedModified: [],
        stagedDeleted: [],
        unstagedModified: [],
        unstagedDeleted: [],
        untracked: [],
      },
    };
  }
  const branches = branchList(controller.host, REPO_ROOT);
  const logEntries = log(controller.host, REPO_ROOT, 8);
  const currentStatus = status(controller.host, REPO_ROOT);
  return { repoReady, summary, branches, logEntries, currentStatus };
};

const renderStorageCards = () => {
  elements.storageCards.innerHTML = "";
  for (const controller of storageControllers) {
    const card = document.createElement("button");
    card.type = "button";
    card.className = `storage-card ${controller.accentClass} ${
      controller.id === state.activeStorageId ? "active" : ""
    }`;
    const summary = controller.summarize();
    card.innerHTML = `
      <h3>${controller.title}</h3>
      <p>${controller.description}</p>
      <div class="storage-meta-row">
        <span class="storage-meta">${controller.accentTone}</span>
        <span class="storage-meta">${summary.fileCount} files</span>
        <span class="storage-meta">${summary.gitObjectCount} git objects</span>
      </div>
    `;
    card.addEventListener("click", async () => {
      state.activeStorageId = controller.id;
      if (!controller.ready) {
        try {
          await controller.hydrate();
          logEvent(`Loaded ${controller.title} state`, "info");
        } catch (error) {
          logEvent(`Failed to load ${controller.title}: ${error.message}`, "error");
        }
      }
      if (!loadSnapshotIntoEditor()) {
        state.fileContent = sampleNotes;
      }
      render();
    });
    elements.storageCards.append(card);
  }
};

const renderStatus = (view) => {
  if (!view.repoReady) {
    elements.statusView.innerHTML = `<p class="status-empty">Create the sample repo to start staging and committing files.</p>`;
    return;
  }
  const groups = collectStatusGroups(view.currentStatus)
    .filter(([, items]) => items.length > 0)
    .map(([title, items]) => `
      <article class="status-group">
        <h4>${title}</h4>
        <ul class="status-list">${items.map((item) => `<li><code>${item}</code></li>`).join("")}</ul>
      </article>
    `)
    .join("");
  elements.statusView.innerHTML = groups || `
    <article class="status-group status-group-clean">
      <h4>Working tree clean</h4>
      <p class="status-empty">No staged or unstaged changes right now.</p>
    </article>
  `;
};

const renderHistory = (view) => {
  if (!view.repoReady || view.logEntries.length === 0) {
    elements.historyView.innerHTML = `<p class="history-empty">No commits yet.</p>`;
    return;
  }
  elements.historyView.innerHTML = view.logEntries.slice(0, 4).map((entry) => `
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

const renderSnapshot = (controller, view) => {
  const summary = view.summary;
  const workingFiles = summary.workingFiles.length
    ? `<ul>${summary.workingFiles.map((path) => {
      const relative = trimRelativePath(path.replace(`${REPO_ROOT}/`, ""));
      return `<li><button class="snapshot-chip" data-path="${relative}" type="button">${relative}</button></li>`;
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
        <li>mode: ${controller.accentTone}</li>
      </ul>
    </article>
  `;

  for (const button of elements.snapshotView.querySelectorAll("[data-path]")) {
    button.addEventListener("click", () => {
      state.filePath = button.dataset.path;
      if (!loadSnapshotIntoEditor()) {
        logEvent(`File ${state.filePath} is not present in this repo`, "error");
      }
      render();
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
  const controller = getActiveController();
  const view = readControllerView(controller);
  const currentBranch = view.branches.find((branch) => branch.isCurrent)?.name ?? "main";

  renderStorageCards();
  elements.consoleTitle.textContent = controller.title;
  elements.consoleSubtitle.textContent = controller.description;
  elements.storageBanner.textContent = controller.getBanner();
  elements.connectStorage.textContent = controller.id === "filesystem"
    ? controller.persistence.isConnected
      ? `Connected: ${controller.persistence.connectedName}`
      : controller.persistence.connectLabel
    : controller.persistence.connectLabel;
  elements.connectStorage.disabled = controller.id !== "filesystem";
  elements.reloadStorage.disabled = controller.id === "memory";
  elements.filePath.value = state.filePath;
  elements.fileContent.value = state.fileContent;
  elements.commitMessage.value = state.commitMessage;
  elements.branchName.value = state.branchName;
  renderStatus(view);
  renderHistory(view);
  renderSnapshot(controller, view);
  renderBranchStrip(view);
  renderEventLog();

  const repoReady = view.repoReady;
  elements.loadFile.disabled = !repoReady;
  elements.saveFile.disabled = !repoReady;
  elements.stageFile.disabled = !repoReady;
  elements.stageAll.disabled = !repoReady;
  elements.commitFile.disabled = !repoReady;
  elements.createBranch.disabled = !repoReady;
  elements.checkoutBranch.disabled = !repoReady;
  elements.clearStorage.disabled = controller.id === "memory" && !repoReady;

  const statusSummary = summarizeStatus(view.currentStatus);
  const bannerBits = [
    `HEAD ${currentBranch}`,
    `${statusSummary.staged} staged`,
    `${statusSummary.unstaged} unstaged`,
    `${statusSummary.untracked} untracked`,
  ];
  if (controller.persistence.connectedName) {
    bannerBits.push(`folder ${controller.persistence.connectedName}`);
  }
  elements.storageBanner.innerHTML = bannerBits.map((value) => (
    `<span class="status-chip">${value}</span>`
  )).join(" ");
};

const createSampleRepo = async (controller) => {
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
};

elements.connectStorage.addEventListener("click", async () => {
  const controller = getActiveController();
  if (controller.id !== "filesystem") return;
  try {
    await controller.connect();
    if (!loadSnapshotIntoEditor()) {
      state.fileContent = sampleNotes;
    }
    logEvent(
      controller.persistence.isConnected
        ? `Connected local folder ${controller.persistence.connectedName}`
        : "Local folder disconnected",
      "info",
    );
    render();
  } catch (error) {
    logEvent(`Folder connection failed: ${error.message}`, "error");
    render();
  }
});

elements.reloadStorage.addEventListener("click", async () => {
  const controller = getActiveController();
  try {
    await controller.hydrate();
    if (!loadSnapshotIntoEditor()) {
      state.fileContent = sampleNotes;
    }
    logEvent(`Reloaded ${controller.title} storage`, "info");
    render();
  } catch (error) {
    logEvent(`Reload failed: ${error.message}`, "error");
    render();
  }
});

elements.clearStorage.addEventListener("click", async () => {
  await runMutation("Cleared demo storage", async (controller) => {
    await controller.clear();
    state.fileContent = sampleNotes;
  });
});

elements.seedRepo.addEventListener("click", async () => {
  await runMutation("Created sample repo", createSampleRepo);
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
  await runMutation(`Saved ${state.filePath}`, async (controller) => {
    controller.host.writeString(absoluteFilePath(state.filePath), state.fileContent);
  });
});

elements.stageFile.addEventListener("click", async () => {
  await runMutation(`Staged ${state.filePath}`, async (controller) => {
    add(controller.host, REPO_ROOT, [state.filePath]);
  });
});

elements.stageAll.addEventListener("click", async () => {
  await runMutation("Staged all working tree changes", async (controller) => {
    add(controller.host, REPO_ROOT, ["."]);
  });
});

elements.commitFile.addEventListener("click", async () => {
  await runMutation(`Committed ${state.commitMessage}`, async (controller) => {
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
  await runMutation(`Created branch ${state.branchName}`, async (controller) => {
    branchCreate(controller.host, REPO_ROOT, state.branchName);
    state.selectedBranch = state.branchName;
  });
});

elements.checkoutBranch.addEventListener("click", async () => {
  await runMutation(`Checked out ${state.branchName}`, async (controller) => {
    checkout(controller.host, REPO_ROOT, state.branchName);
    state.selectedBranch = state.branchName;
  });
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

const boot = async () => {
  for (const controller of storageControllers) {
    try {
      await controller.hydrate();
    } catch (error) {
      console.error(error);
      logEvent(`Failed to load ${controller.title}: ${error.message}`, "error");
    }
  }
  loadSnapshotIntoEditor();
  render();
  logEvent("Demo ready", "info");
  render();
};

void boot();
