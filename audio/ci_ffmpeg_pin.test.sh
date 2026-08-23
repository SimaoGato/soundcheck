#!/usr/bin/env bash
# Regression test: the CI workflow must pin its runner image (not float on
# "ubuntu-latest") and assert ffmpeg's major version before generating
# clips. generate.sh's header comment warns a different ffmpeg version can
# produce different seeded pink-noise output, breaking AC7 determinism
# across machines — without this pin, a future Ubuntu image bump could
# silently change the apt-installed ffmpeg version with no test catching
# it. See PR #1 review comment on audio/generate.sh:6-8 vs
# .github/workflows/audio-checks.yml:21.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/audio-checks.yml"

failures=()

if grep -qE '^\s*runs-on:\s*ubuntu-latest\s*$' "$WORKFLOW"; then
  failures+=("runs-on: ubuntu-latest floats to a new image with no PR diff; pin a fixed version (e.g. ubuntu-24.04)")
fi

grep -qE '^\s*runs-on:\s*ubuntu-[0-9]+\.[0-9]+\s*$' "$WORKFLOW" \
  || failures+=("no fixed runs-on: ubuntu-<version> pin found")

grep -qE 'ffmpeg -version' "$WORKFLOW" \
  || failures+=("no ffmpeg version check step found — a drifted ffmpeg version would go uncaught")

if [ "${#failures[@]}" -gt 0 ]; then
  echo "FAIL: CI workflow doesn't guard against silent ffmpeg version drift:" >&2
  printf ' - %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "PASS: CI workflow pins its runner image and checks ffmpeg's version"
