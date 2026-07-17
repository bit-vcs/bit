import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";

const readQuotedField = (source, field) => {
  const match = source.match(new RegExp(`^${field}\\s*=\\s*"([^"]+)"\\s*$`, "m"));
  return match?.[1];
};

const loadMoonMod = (manifestPath) => {
  const source = readFileSync(manifestPath, "utf8");
  const imports = source.match(/^import\s*\{([\s\S]*?)^\}/m)?.[1] ?? "";
  const deps = Object.fromEntries(
    [...imports.matchAll(/^\s*"([^"@]+)@([^"]+)",?\s*$/gm)]
      .map(([, name, version]) => [name, version]),
  );
  return {
    name: readQuotedField(source, "name"),
    version: readQuotedField(source, "version"),
    source: readQuotedField(source, "source"),
    deps,
  };
};

export const loadWorkspaceModules = (root = process.cwd()) => (
  readdirSync(path.join(root, "modules"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const directory = path.join(root, "modules", entry.name);
      const moonModPath = path.join(directory, "moon.mod");
      const legacyManifestPath = path.join(directory, "moon.mod.json");
      if (existsSync(moonModPath)) {
        return {
          directory,
          manifestPath: moonModPath,
          ...loadMoonMod(moonModPath),
        };
      }
      if (!existsSync(legacyManifestPath)) {
        return null;
      }
      const manifest = JSON.parse(readFileSync(legacyManifestPath, "utf8"));
      return { directory, manifestPath: legacyManifestPath, ...manifest };
    })
    .filter(Boolean)
);

export const topologicalPublishLayers = (modules) => {
  const byName = new Map(modules.map((module) => [module.name, module]));
  const internalNames = new Set(byName.keys());
  const remaining = new Set(internalNames);
  const published = new Set();
  const layers = [];

  while (remaining.size > 0) {
    const ready = [...remaining]
      .filter((name) => Object.keys(byName.get(name).deps ?? {})
        .filter((dependency) => internalNames.has(dependency))
        .every((dependency) => published.has(dependency)))
      .sort();

    if (ready.length === 0) {
      throw new Error(
        `workspace module dependency cycle: ${[...remaining].sort().join(", ")}`,
      );
    }

    const layer = [];
    for (const name of ready) {
      remaining.delete(name);
      published.add(name);
      layer.push(byName.get(name));
    }
    layers.push(layer);
  }

  return layers;
};

export const topologicalPublishOrder = (modules) => (
  topologicalPublishLayers(modules).flat()
);
