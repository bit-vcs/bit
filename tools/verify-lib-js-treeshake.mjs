import assert from "node:assert/strict";
import { gzipSync } from "node:zlib";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const MAX_MINIMAL_RAW_BYTES = 161_000;
const MAX_MINIMAL_GZIP_BYTES = 40_000;
const MAX_MINIMAL_RATIO = 0.70;

function readSize(path) {
  const source = readFileSync(path);
  return {
    rawBytes: source.byteLength,
    gzipBytes: gzipSync(source, { mtime: 0 }).byteLength,
  };
}

export async function verifyTreeshakeBundles() {
  const minimal = readSize("target/lib-js-minimal.bundle.mjs");
  const gitOps = readSize("target/lib-js-git-ops.bundle.mjs");

  assert(
    minimal.rawBytes < gitOps.rawBytes,
    `expected minimal raw bundle to be smaller: minimal=${minimal.rawBytes} gitOps=${gitOps.rawBytes}`,
  );
  assert(
    minimal.gzipBytes < gitOps.gzipBytes,
    `expected minimal gzip bundle to be smaller: minimal=${minimal.gzipBytes} gitOps=${gitOps.gzipBytes}`,
  );
  assert(
    minimal.rawBytes <= MAX_MINIMAL_RAW_BYTES,
    `minimal raw bundle exceeded guardrail: actual=${minimal.rawBytes} max=${MAX_MINIMAL_RAW_BYTES}`,
  );
  assert(
    minimal.gzipBytes <= MAX_MINIMAL_GZIP_BYTES,
    `minimal gzip bundle exceeded guardrail: actual=${minimal.gzipBytes} max=${MAX_MINIMAL_GZIP_BYTES}`,
  );
  assert(
    minimal.rawBytes / gitOps.rawBytes <= MAX_MINIMAL_RATIO,
    `minimal raw ratio exceeded guardrail: minimal=${minimal.rawBytes} gitOps=${gitOps.rawBytes} ratio=${minimal.rawBytes / gitOps.rawBytes}`,
  );
  assert(
    minimal.gzipBytes / gitOps.gzipBytes <= MAX_MINIMAL_RATIO,
    `minimal gzip ratio exceeded guardrail: minimal=${minimal.gzipBytes} gitOps=${gitOps.gzipBytes} ratio=${minimal.gzipBytes / gitOps.gzipBytes}`,
  );

  return { minimal, gitOps };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await verifyTreeshakeBundles();
  console.log(JSON.stringify(result, null, 2));
}
