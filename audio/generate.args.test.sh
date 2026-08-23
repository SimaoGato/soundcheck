#!/usr/bin/env bash
# Regression test for generate.sh's argument handling: an unrecognized first
# argument must exit non-zero, not silently fall through to the plain-generate
# branch. AC7's CI check depends on the literal string match against
# `--verify` in the workflow file, so a typo there must fail loud rather than
# report a false green. See PR #1 review comment on audio/generate.sh:97.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_SH="$ROOT_DIR/generate.sh"

if output="$(bash -c '
  ffmpeg() { :; }
  export -f ffmpeg
  "$1" --verfy
' _ "$GENERATE_SH" 2>&1)"; then
  echo "FAIL: generate.sh accepted an unrecognized argument (--verfy) instead of erroring. Output: $output" >&2
  exit 1
fi

if [[ "$output" != *"unrecognized argument"* ]]; then
  echo "FAIL: generate.sh's error message didn't mention the unrecognized argument. Output: $output" >&2
  exit 1
fi

echo "PASS: generate.sh errors loudly on an unrecognized argument"
