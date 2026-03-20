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

const state = {
  filePath: DEFAULT_FILE_PATH,
  fileContent: sampleNotes,
  commitMessage: "demo: update notes",
  branchName: "feature/demo",
  selectedBranch: "main",
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

const runMutation = async (label, operation) => {
  try {
    const result = await operation();
    await controller.persist();
    logEvent(label, "info");
    render(result);
  } catch (error) {
    console.error(error);
    logEvent(`${label}: ${error instanceof Error ? error.message : String(error)}`, "error");
    render();
  }
};

const renderCommitMeta = (view) => {
  const currentBranch = view.branches.find((branch) => branch.isCurrent)?.name ?? "main";
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

  elements.consoleTitle.textContent = "IndexedDB demo";
  elements.consoleSubtitle.textContent = "Changes persist in this browser and the sample repo is created automatically.";
  elements.filePath.value = state.filePath;
  elements.fileContent.value = state.fileContent;
  elements.commitMessage.value = state.commitMessage;
  elements.branchName.value = state.branchName;

  renderCommitMeta(view);
  renderChangeMap(view);
  renderHistory(view);
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

  elements.storageBanner.innerHTML = `
    <span class="status-chip">IndexedDB persistence</span>
    <span class="status-chip">current file ${state.filePath}</span>
    <span class="status-chip">saved ${timestampLabel(controller.lastSavedAt)}</span>
  `;
};

elements.resetRepo.addEventListener("click", async () => {
  await runMutation("Reset sample repo", async () => {
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
  await runMutation(`Saved ${state.filePath}`, async () => {
    controller.host.writeString(absoluteFilePath(state.filePath), state.fileContent);
  });
});

elements.stageFile.addEventListener("click", async () => {
  await runMutation(`Staged ${state.filePath}`, async () => {
    add(controller.host, REPO_ROOT, [state.filePath]);
  });
});

elements.stageAll.addEventListener("click", async () => {
  await runMutation("Staged all working tree changes", async () => {
    add(controller.host, REPO_ROOT, ["."]);
  });
});

elements.commitFile.addEventListener("click", async () => {
  await runMutation(`Committed ${state.commitMessage}`, async () => {
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
  await runMutation(`Created branch ${state.branchName}`, async () => {
    branchCreate(controller.host, REPO_ROOT, state.branchName);
    state.selectedBranch = state.branchName;
  });
});

elements.checkoutBranch.addEventListener("click", async () => {
  await runMutation(`Checked out ${state.branchName}`, async () => {
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

  render();
  logEvent("Demo ready", "info");
  render();
};

void boot();
