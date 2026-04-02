import { basename } from "node:path";
import { readFileSync } from "node:fs";

export const GIT_COMPAT_TASK_ID = "git-compat";
export const GIT_TEST_SUITE_PREFIX = "third_party/git/t/";

export function parseAllowlistEntries(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith("#"));
}

export function readAllowlistEntries(path = "tools/git-test-allowlist.txt") {
  return parseAllowlistEntries(readFileSync(path, "utf8"));
}

export function toGitCompatSuite(scriptName) {
  return `${GIT_TEST_SUITE_PREFIX}${scriptName}`;
}

export function toFlakerTest(scriptName) {
  return {
    suite: toGitCompatSuite(scriptName),
    testName: scriptName,
    taskId: GIT_COMPAT_TASK_ID,
  };
}

export function listFlakerGitCompatTests(path = "tools/git-test-allowlist.txt") {
  return readAllowlistEntries(path).map(toFlakerTest);
}

function normalizeCandidate(value) {
  if (!value) return null;
  let candidate = String(value).trim();
  if (!candidate) return null;
  if (candidate.startsWith(GIT_TEST_SUITE_PREFIX)) {
    candidate = candidate.slice(GIT_TEST_SUITE_PREFIX.length);
  }
  if (candidate.startsWith("t/")) {
    candidate = candidate.slice(2);
  }
  return basename(candidate);
}

export function normalizeSelectedScript(test, allowlistSet) {
  const candidates = [
    normalizeCandidate(test?.testName),
    normalizeCandidate(test?.suite),
  ].filter(Boolean);

  for (const candidate of candidates) {
    if (allowlistSet.has(candidate)) {
      return candidate;
    }
  }

  throw new Error(
    `Selected test is not in git compat allowlist: ${JSON.stringify(test)}`,
  );
}

export function normalizeSelectedScripts(tests, allowlistEntries) {
  const allowlistSet = new Set(allowlistEntries);
  const selected = [];
  const seen = new Set();

  for (const test of tests) {
    const script = normalizeSelectedScript(test, allowlistSet);
    if (seen.has(script)) continue;
    seen.add(script);
    selected.push(script);
  }

  return selected;
}
