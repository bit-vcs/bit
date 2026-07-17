import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

test("Moon package publishing allows isolated package verification to resolve dependencies", () => {
  const source = readFileSync(new URL("./publish-moon.mjs", import.meta.url), "utf8");

  assert.match(
    source,
    /run\("moon", \["-C", path\.relative\(root, module\.directory\), "publish"\]\);/,
  );
  assert.doesNotMatch(source, /"publish", "--frozen"/);
});
