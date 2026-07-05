#!/bin/bash
# SessionStart hook: ensure a MoonBit toolchain new enough for the
# MOONBIT_NEW_NATIVE=1 native backend (set in .claude/settings.json).
#
# `moon test --target native` otherwise compiles its test drivers through the
# bundled `tcc -run`, which crashes in this environment. MOONBIT_NEW_NATIVE=1
# routes native builds through the system `cc`/`clang` instead, but that flag
# is only wired into moonc from toolchain 0.1.20260629 onward. This container
# ships an older default (0.1.20260608) where the flag is inert, so upgrade to
# the latest toolchain when needed.
set -euo pipefail

# Only relevant in Claude Code on the web (remote) environments.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

export PATH="$HOME/.moon/bin:$PATH"

# First toolchain release where MOONBIT_NEW_NATIVE=1 takes effect.
MIN_DATE=20260629

extract_date() {
  moon version 2>/dev/null | grep -oE '0\.1\.[0-9]{8}' | head -1 \
    | grep -oE '[0-9]{8}$' || echo 0
}

cur_date="$(extract_date)"
if [ "${cur_date:-0}" -lt "$MIN_DATE" ]; then
  echo "moonbit ${cur_date} < ${MIN_DATE}: upgrading to latest for MOONBIT_NEW_NATIVE support..."
  curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
  export PATH="$HOME/.moon/bin:$PATH"
  echo "moonbit upgraded to $(extract_date)"
else
  echo "moonbit ${cur_date} already supports MOONBIT_NEW_NATIVE"
fi

# A freshly cloned container loses the cached module registry/deps; refresh it
# so builds resolve on the first invocation.
moon update >/dev/null 2>&1 || true
