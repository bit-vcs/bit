#!/usr/bin/env node
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const bitJs = join(__dirname, "..", "bit.js");

// MoonBit JS output uses process.argv directly
await import(bitJs);
