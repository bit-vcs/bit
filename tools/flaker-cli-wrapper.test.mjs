import assert from "node:assert/strict";
import test from "node:test";

import {
  formatFlakerFailure,
  isGlobResolverFailure,
  isMissingFlakerCommand,
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
    1,
  );

  assert.match(message, /glob resolver support/i);
  assert.match(message, /FLAKER_CMD/);
  assert.match(message, /PR #14 or newer/);
});

test("formatFlakerFailure preserves other failures", () => {
  assert.equal(
    formatFlakerFailure("plain failure", "flaker", 1),
    "plain failure",
  );
});

test("isMissingFlakerCommand detects missing CLI errors", () => {
  assert.equal(
    isMissingFlakerCommand("/bin/sh: flaker: command not found", 127),
    true,
  );
  assert.equal(
    isMissingFlakerCommand("plain failure", 1),
    false,
  );
});

test("formatFlakerFailure rewrites missing flaker command errors", () => {
  const message = formatFlakerFailure(
    "/bin/sh: flaker: command not found",
    "flaker",
    127,
  );

  assert.match(message, /flaker CLI is required/i);
  assert.match(message, /FLAKER_CMD/);
});
