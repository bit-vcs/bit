import assert from "node:assert/strict";
import test from "node:test";

import {
  formatFlakerFailure,
  isGlobResolverFailure,
} from "./flaker-cli-wrapper.mjs";

test("isGlobResolverFailure detects unsupported glob resolver errors", () => {
  assert.equal(
    isGlobResolverFailure("Error: Unknown resolver: glob"),
    true,
  );
  assert.equal(
    isGlobResolverFailure("something else failed"),
    false,
  );
});

test("formatFlakerFailure rewrites glob resolver failures with guidance", () => {
  const message = formatFlakerFailure(
    "Error: Unknown resolver: glob",
    "flaker",
  );

  assert.match(message, /glob resolver support/i);
  assert.match(message, /FLAKER_CMD/);
  assert.match(message, /PR #14 or newer/);
});

test("formatFlakerFailure preserves other failures", () => {
  assert.equal(
    formatFlakerFailure("plain failure", "flaker"),
    "plain failure",
  );
});
