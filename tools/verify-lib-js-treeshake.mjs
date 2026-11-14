import assert from "node:assert/strict";
import { gzipSync } from "node:zlib";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

// Raised from 161_000 -> 163_000 in #162 for async-rebase export plumbing
// that isn't fully tree-shaken out of the minimal bundle. Raised to 165_000
// for the AsyncFileSystem/AsyncRepoFileSystem/AsyncHttpClient types, which
// hit the same tree-shaking limitation. Rebaselined again in #179 when the
// toolchain moved to moonc 0.10.13 with moonbitlang/x 0.5 / async 0.22: the
// same exports now emit ~174_500 raw / ~40_300 gzip bytes. Rebaselined to
// 186_000 when the toolchain moved to moonc 0.10.17 with moonbitlang/x 0.5.6
// / async 0.22.5: the same exports now emit ~180_700 raw bytes. Rebaselined to
// 216_000 raw / 52_000 gzip when mizchi/zlib was replaced by
// moonbitlang/core/compress: with moonc 0.10.20 the minimal bundle is
// ~185_500 raw / ~42_500 gzip on mizchi/zlib and ~210_500 raw / ~49_600 gzip
// on core compress, whose inflate (IncrementalDecoder + MemDecoder) is the
// whole difference. Headroom is intentional so small future additions don't
// require another bump.
const MAX_MINIMAL_RAW_BYTES = 216_000;
const MAX_MINIMAL_GZIP_BYTES = 52_000;
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
