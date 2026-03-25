const STATUS_GROUPS = [
  ["stagedAdded", "staged added"],
  ["stagedModified", "staged modified"],
  ["stagedDeleted", "staged deleted"],
  ["unstagedModified", "unstaged modified"],
  ["unstagedDeleted", "unstaged deleted"],
  ["untracked", "untracked"],
];

export const tokenizeCommand = (input) => {
  const source = String(input ?? "").trim();
  if (!source) return [];
  const tokens = [];
  let current = "";
  let quote = null;

  for (let index = 0; index < source.length; index += 1) {
    const char = source[index];
    if (quote) {
      if (char === "\\" && index + 1 < source.length) {
        current += source[index + 1];
        index += 1;
        continue;
      }
      if (char === quote) {
        quote = null;
        continue;
      }
      current += char;
      continue;
    }

    if (char === "'" || char === "\"") {
      quote = char;
      continue;
    }
    if (/\s/.test(char)) {
      if (current.length > 0) {
        tokens.push(current);
        current = "";
      }
      continue;
    }
    if (char === "\\" && index + 1 < source.length) {
      current += source[index + 1];
      index += 1;
      continue;
    }
    current += char;
  }

  if (quote) {
    throw new Error("unterminated quoted string");
  }
  if (current.length > 0) {
    tokens.push(current);
  }
  return tokens;
};

const withPrefixesStripped = (tokens) => {
  if (tokens[0] === "bit" || tokens[0] === "git") {
    return tokens.slice(1);
  }
  return tokens;
};

const statusLines = (status) => {
  const lines = [];
  for (const [key, label] of STATUS_GROUPS) {
    const items = Array.from(status?.[key] ?? []);
    if (items.length === 0) continue;
    lines.push(`${label}:`);
    for (const item of items) {
      lines.push(`  ${item}`);
    }
  }
  return lines.length > 0 ? lines : ["working tree clean"];
};

const logLines = (entries) => (
  entries.length > 0
    ? entries.map((entry) => `${entry.id.slice(0, 7)} ${entry.message}`)
    : ["no commits yet"]
);

const sessionLines = (sessions) => (
  sessions.length > 0
    ? sessions.map((session) => (
      `${session.sessionId}  ${session.label}  rev:${session.lastRevision}`
    ))
    : ["no hosted editors"]
);

const branchLines = (branches) => (
  branches.length > 0
    ? branches.map((branch) => `${branch.isCurrent ? "*" : " "} ${branch.name}`)
    : ["no branches"]
);

const helpLines = () => [
  "help",
  "status",
  "ls",
  "open <path>",
  "save",
  "add [path|.]",
  "commit <message>",
  "log [count]",
  "branches",
  "branch <name>",
  "checkout <name>",
  "relay host [label]",
  "relay sessions",
  "relay connect <sessionId>",
  "relay pull",
  "reset",
];

export async function runPlaygroundCommand(app, input) {
  const rawTokens = tokenizeCommand(input);
  if (rawTokens.length === 0) {
    return { ok: true, lines: [] };
  }

  const tokens = withPrefixesStripped(rawTokens);
  if (tokens.length === 0) {
    return { ok: true, lines: helpLines() };
  }

  try {
    const [command, ...args] = tokens;
    switch (command) {
      case "help":
        return { ok: true, lines: helpLines() };
      case "status":
        return { ok: true, lines: statusLines(app.getView().currentStatus) };
      case "ls":
        return { ok: true, lines: app.listFiles() };
      case "open": {
        const targetPath = args.join(" ");
        if (!targetPath) throw new Error("open requires a path");
        await app.openFile(targetPath);
        return { ok: true, lines: [`opened ${targetPath}`] };
      }
      case "save":
        await app.saveEditor();
        return { ok: true, lines: [`saved ${app.getEditor().path}`] };
      case "add":
      case "stage": {
        const path = args[0] ?? app.getEditor().path;
        await app.stagePaths([path]);
        return { ok: true, lines: [`staged ${path}`] };
      }
      case "commit": {
        const message = args.join(" ").trim();
        if (!message) throw new Error("commit requires a message");
        const commitId = await app.commit(message);
        return { ok: true, lines: [`committed ${commitId.slice(0, 7)} ${message}`] };
      }
      case "log": {
        const count = args[0] ? Math.max(1, Number.parseInt(args[0], 10) || 8) : 8;
        return { ok: true, lines: logLines(app.listHistory(count)) };
      }
      case "branches":
        return { ok: true, lines: branchLines(app.listBranches()) };
      case "branch": {
        const name = args.join(" ").trim();
        if (!name) {
          return { ok: true, lines: branchLines(app.listBranches()) };
        }
        await app.createBranch(name);
        return { ok: true, lines: [`created branch ${name}`] };
      }
      case "checkout": {
        const name = args.join(" ").trim();
        if (!name) throw new Error("checkout requires a branch name");
        await app.checkoutBranch(name);
        return { ok: true, lines: [`checked out ${name}`] };
      }
      case "relay": {
        const [subcommand, ...relayArgs] = args;
        switch (subcommand) {
          case "host": {
            const label = relayArgs.join(" ").trim() || null;
            const session = await app.startHosting(label);
            return { ok: true, lines: [`hosting ${session.sessionId} ${session.label}`] };
          }
          case "sessions": {
            const sessions = await app.refreshSessions();
            return { ok: true, lines: sessionLines(sessions) };
          }
          case "connect": {
            const sessionId = relayArgs[0];
            if (!sessionId) throw new Error("relay connect requires a session id");
            await app.connectSession(sessionId);
            return { ok: true, lines: [`connected ${sessionId}`] };
          }
          case "pull": {
            const updated = await app.pullConnectedSession();
            return { ok: true, lines: [updated ? "pulled latest snapshot" : "already up to date"] };
          }
          default:
            throw new Error("relay subcommands: host, sessions, connect, pull");
        }
      }
      case "reset":
        await app.resetSampleRepo();
        return { ok: true, lines: ["reset sample repo"] };
      default:
        throw new Error(`unknown command: ${command}`);
    }
  } catch (error) {
    return {
      ok: false,
      lines: [error instanceof Error ? error.message : String(error)],
    };
  }
}
