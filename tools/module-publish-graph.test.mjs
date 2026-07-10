import assert from "node:assert/strict";
import test from "node:test";

import {
  loadWorkspaceModules,
  topologicalPublishOrder,
} from "./module-publish-graph.mjs";

test("workspace modules form a version-aligned publish DAG", () => {
  const modules = loadWorkspaceModules();
  const names = new Set(modules.map((module) => module.name));
  const versions = new Set(modules.map((module) => module.version));

  assert.equal(versions.size, 1, "workspace module versions must be aligned");
  const [workspaceVersion] = versions;
  for (const module of modules) {
    for (const [dependency, version] of Object.entries(module.deps ?? {})) {
      if (names.has(dependency)) {
        assert.equal(
          version,
          workspaceVersion,
          `${module.name} must use the workspace version for ${dependency}`,
        );
      }
    }
  }

  const ordered = topologicalPublishOrder(modules);
  assert.equal(ordered.length, modules.length);
  assert.equal(ordered.at(-1).name, "mizchi/bit");
});
