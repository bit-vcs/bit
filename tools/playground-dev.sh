#!/usr/bin/env bash
# Boot the Vite-powered playground after building the JS lib.
set -euo pipefail

moon build --target js --release src/lib
if [ ! -d node_modules ]; then
  pnpm install
fi
pnpm run playground:dev
