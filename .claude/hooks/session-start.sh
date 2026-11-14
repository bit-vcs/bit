#!/bin/bash
# SessionStart hook: install the MoonBit toolchain pinned by flake.lock.
#
# CI, the dev shell and the nix build all take MoonBit from the flake's
# `moonbit` package (moonbit-overlay, pinned in flake.lock). Nix cannot
# evaluate the flake in Claude Code on the web (GitHub tarball downloads are
# blocked), so this hook resolves the same toolchain version from the locked
# moonbit-overlay revision and installs exactly that release with the
# official installer.
#
# A pinned toolchain also satisfies MOONBIT_NEW_NATIVE=1 (set in
# .claude/settings.json), which needs 0.1.20260629 or newer; if the pin
# cannot be resolved, fall back to the old behaviour of upgrading to the
# latest release when the installed one is too old for that flag.
set -euo pipefail

# Only relevant in Claude Code on the web (remote) environments.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

export PATH="$HOME/.moon/bin:$PATH"
project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

# Installed toolchain in moonbit-overlay's version format:
# v<moonc version>+<moon rev>, e.g. v0.10.20+65efd5b93+940aa18.
installed_version() {
  local moonc moon_rev
  moonc="$(moonc -v 2>/dev/null | awk '{print $1}')" || return 0
  moon_rev="$(moon version 2>/dev/null | sed -nE 's/.*\(([0-9a-f]+) .*/\1/p' | head -1)"
  [ -n "$moonc" ] && [ -n "$moon_rev" ] && echo "${moonc}+${moon_rev}"
}

# Toolchain version pinned by flake.lock (moonbit-overlay's
# versions/toolchains/latest.json at the locked revision).
pinned_version() {
  local rev tmp status=0
  rev="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); r=d["nodes"]["root"]["inputs"]["moonbit-overlay"]; print(d["nodes"][r]["locked"]["rev"])' \
    "$project_dir/flake.lock" 2>/dev/null)" || return 1
  tmp="$(mktemp -d)"
  {
    git -C "$tmp" init -q &&
      git -C "$tmp" fetch -q --depth 1 --filter=blob:none \
        https://github.com/moonbit-community/moonbit-overlay "$rev" &&
      git -C "$tmp" show FETCH_HEAD:versions/toolchains/latest.json |
      python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])'
  } || status=1
  rm -rf "$tmp"
  return "$status"
}

install_moonbit() { # [installer version]
  curl -fsSL https://cli.moonbitlang.com/install/unix.sh |
    MOONBIT_INSTALL_VERSION="${1:-latest}" bash
  export PATH="$HOME/.moon/bin:$PATH"
}

current="$(installed_version || true)"
if pinned="$(pinned_version)" && [ -n "$pinned" ]; then
  if [ "$current" = "$pinned" ]; then
    echo "moonbit ${current} matches flake.lock"
  else
    # The installer names releases <moonc version>, e.g. 0.10.20+65efd5b93.
    release="${pinned#v}"
    release="${release%+*}"
    echo "moonbit ${current:-none} != flake.lock ${pinned}: installing ${release}..."
    install_moonbit "$release"
    echo "moonbit is now $(installed_version)"
  fi
else
  # Could not resolve the pin (offline?): keep MOONBIT_NEW_NATIVE working.
  min_date=20260629
  cur_date="$(moon version 2>/dev/null | grep -oE '0\.1\.[0-9]{8}' | head -1 | grep -oE '[0-9]{8}$' || echo 0)"
  if [ "${cur_date:-0}" -lt "$min_date" ]; then
    echo "could not read the flake.lock pin; moonbit ${cur_date} < ${min_date}: upgrading to latest..."
    install_moonbit latest
  else
    echo "could not read the flake.lock pin; keeping moonbit ${current:-$cur_date}"
  fi
fi

# A freshly cloned container loses the cached module registry/deps; refresh it
# so builds resolve on the first invocation.
moon update >/dev/null 2>&1 || true
