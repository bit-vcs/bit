import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";

import {
  loadWorkspaceModules,
  topologicalPublishOrder,
} from "./module-publish-graph.mjs";

test("workspace modules form a publish DAG with resolvable internal versions", () => {
  const modules = loadWorkspaceModules();
  const byName = new Map(modules.map((module) => [module.name, module]));

  assert.ok(modules.length > 0);
  assert.equal(modules.every((module) => module.manifestPath.endsWith("moon.mod")), true);

  for (const module of modules) {
    for (const [dependency, version] of Object.entries(module.deps ?? {})) {
      if (byName.has(dependency)) {
        assert.equal(
          version,
          byName.get(dependency).version,
          `${module.name} must use ${dependency}'s workspace version`,
        );
      }
    }
  }

  const ordered = topologicalPublishOrder(modules);
  assert.equal(ordered.length, modules.length);
  assert.equal(ordered.at(-1).name, "mizchi/bit");
});

test("mizchi/bit module root is the installable main package", () => {
  const [bit] = loadWorkspaceModules().filter((module) => module.name === "mizchi/bit");
  assert.equal(bit.source, ".");
  assert.equal(existsSync(path.join(bit.directory, "moon.pkg")), true);
  assert.match(
    readFileSync(path.join(bit.directory, "moon.pkg"), "utf8"),
    /pkgtype\(kind: "executable"\)/,
  );
});
