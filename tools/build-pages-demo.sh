#!/usr/bin/env bash
# Stage the GitHub Pages demo artifact under target/pages/.
# Assumes docs/demo/app.js and docs/playground/app.js are already built.
set -euo pipefail

mkdir -p target/pages
cp docs/demo/index.html target/pages/index.html
cp docs/demo/styles.css target/pages/styles.css
cp docs/demo/app.js target/pages/app.js

mkdir -p target/pages/playground
cp docs/playground/index.html target/pages/playground/index.html
cp docs/playground/styles.css target/pages/playground/styles.css
cp docs/playground/app.js target/pages/playground/app.js
