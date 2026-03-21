#!/usr/bin/env node
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const bitCjs = join(__dirname, "..", "bit.cjs");

// MoonBit CLI output assumes CommonJS even when the package itself is ESM.
require(bitCjs);
