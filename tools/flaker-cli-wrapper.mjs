#!/usr/bin/env node

import { spawnSync } from "node:child_process";

export function isGlobResolverFailure(stderr) {
  return String(stderr ?? "").includes("Unknown resolver: glob");
}

export function isMissingFlakerCommand(stderr, status) {
  const text = String(stderr ?? "");
  return status === 127 || /not found/i.test(text);
}

export function formatFlakerFailure(stderr, flakerCommand, status) {
  if (isMissingFlakerCommand(stderr, status)) {
    return [
      `flaker CLI is required, but \`${flakerCommand}\` was not found.`,
      "Install @mizchi/flaker, or point FLAKER_CMD to a local flaker build.",
      "Example: FLAKER_CMD='node /path/to/flaker/dist/cli.js' just flaker-git-compat-affected changed=src/cmd/bit/merge.mbt",
    ].join("\n");
  }

  if (!isGlobResolverFailure(stderr)) {
    return String(stderr ?? "").trim();
  }

  return [
    `This workflow requires flaker with glob resolver support, but \`${flakerCommand}\` does not have it.`,
    "Use mizchi/flaker PR #14 or newer, or point FLAKER_CMD to a local flaker build that includes the glob resolver.",
    "Example: FLAKER_CMD='node /path/to/flaker/dist/cli.js' just flaker-git-compat-affected changed=src/cmd/bit/merge.mbt",
  ].join("\n");
}

function runFlaker(args, flakerCommand) {
  return spawnSync(`${flakerCommand} ${args.map((arg) => JSON.stringify(arg)).join(" ")}`, {
    shell: true,
    stdio: ["inherit", "pipe", "pipe"],
    encoding: "utf8",
  });
}

function main() {
  const args = process.argv.slice(2);
  const flakerCommand = process.env.FLAKER_CMD?.trim() || "flaker";
  const result = runFlaker(args, flakerCommand);

  if (result.stdout) {
    process.stdout.write(result.stdout);
  }

  if (result.status === 0) {
    if (result.stderr) {
      process.stderr.write(result.stderr);
    }
    return;
  }

  const message = formatFlakerFailure(
    result.stderr,
    flakerCommand,
    result.status ?? 1,
  );
  if (message) {
    process.stderr.write(`${message}\n`);
  }
  process.exit(result.status ?? 1);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
