#!/usr/bin/env bash
# Regression test: .nvmrc must pin a Node version new enough to run `expo
# start --android` / `npm run android` without crashing on this sandbox.
#
# This sandbox's default `node` on PATH is v20.11.1 (below package.json's
# `engines.node` floor of >=20.19.4). Below Node v20.12 (when
# `util.styleText` was added), Metro's reporter crashes outright with
# `TypeError: _util.default.styleText is not a function` the first time it
# logs anything (not just a warning banner, unlike `expo lint`/`tsc`/`jest`).
# `nvm use` (reading this repo's .nvmrc) is the documented workaround in
# CLAUDE.md's Environments section. If .nvmrc ever drifts below
# package.json's engines floor — or below the v20.12 styleText floor
# specifically — that workaround silently stops working and the crash comes
# back with no test catching it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVMRC="$ROOT_DIR/.nvmrc"
PACKAGE_JSON="$ROOT_DIR/package.json"
STYLETEXT_FLOOR="20.12.0"

[ -f "$NVMRC" ] || {
  echo "FAIL: .nvmrc is missing — 'nvm use' has nothing to pin to" >&2
  exit 1
}

nvmrc_version="$(tr -d '[:space:]' <"$NVMRC")"
engines_min="$(node -e "console.log(require('$PACKAGE_JSON').engines.node.replace(/^>=/, ''))")"

lowest_of() {
  # Prints the lower of two dotted version strings.
  printf '%s\n%s\n' "$1" "$2" | sort -V | head -1
}

failures=()

if [ "$(lowest_of "$nvmrc_version" "$engines_min")" != "$engines_min" ]; then
  failures+=(".nvmrc pins $nvmrc_version, below package.json's engines.node floor of $engines_min")
fi

if [ "$(lowest_of "$nvmrc_version" "$STYLETEXT_FLOOR")" != "$STYLETEXT_FLOOR" ]; then
  failures+=(".nvmrc pins $nvmrc_version, below Node $STYLETEXT_FLOOR (util.styleText) — Metro's reporter crashes outright below this version")
fi

if [ "${#failures[@]}" -gt 0 ]; then
  echo "FAIL: .nvmrc no longer pins a working dev-mode Node version:" >&2
  printf ' - %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "PASS: .nvmrc ($nvmrc_version) satisfies both the engines.node floor and the util.styleText floor"
