import { existsSync, readFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import {
  loadWorkspaceModules,
  topologicalPublishLayers,
} from "./module-publish-graph.mjs";

const root = path.resolve(import.meta.dirname, "..");
const modules = loadWorkspaceModules(root);
const layers = topologicalPublishLayers(modules);

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 128 * 1024 * 1024,
    ...options,
  });
  if (result.status !== 0) {
    const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`
      .trim()
      .split("\n")
      .slice(-60)
      .join("\n");
    throw new Error(`${command} ${args.join(" ")} failed\n${output}`);
  }
  return result;
};

const registryIndexPath = (name) => path.join(
  os.homedir(),
  ".moon",
  "registry",
  "index",
  "user",
  `${name}.index`,
);

const registryHasVersion = (module) => {
  const indexPath = registryIndexPath(module.name);
  if (!existsSync(indexPath)) {
    return false;
  }
  return readFileSync(indexPath, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => JSON.parse(line))
    .some((entry) => entry.version === module.version);
};

const refreshRegistry = () => {
  run("moon", ["update"]);
};

const waitForLayer = async (layer) => {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    refreshRegistry();
    if (layer.every(registryHasVersion)) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000 * (attempt + 1)));
  }
  const missing = layer.filter((module) => !registryHasVersion(module));
  throw new Error(
    `published modules did not reach the registry index: ${missing.map((module) => module.name).join(", ")}`,
  );
};

run("moon", ["whoami"], { stdio: "inherit" });
const gitStatus = run("git", ["status", "--porcelain"]);
if (gitStatus.stdout.trim() !== "") {
  throw new Error("refusing to publish from a dirty worktree");
}
refreshRegistry();

let completed = 0;
for (const layer of layers) {
  let changed = false;
  for (const module of layer) {
    completed += 1;
    if (registryHasVersion(module)) {
      console.log(`[${completed}/${modules.length}] ${module.name}@${module.version} already published`);
      continue;
    }
    console.log(`[${completed}/${modules.length}] publishing ${module.name}@${module.version}`);
    run("moon", ["-C", path.relative(root, module.directory), "publish", "--frozen"]);
    changed = true;
  }
  if (changed) {
    await waitForLayer(layer);
  }
}
