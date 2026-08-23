#!/usr/bin/env bash
# Mutation test for manifest.sh's AC5/AC6/AC7 self-check (the "no orphan
# assets, no dangling manifest entries, both directions" logic) — same
# rationale as check.assertions.test.sh per CLAUDE.md's "Conventions &
# gotchas" on shell-script regression tests: without this, a broken
# comparison in verify_manifest() would silently rubber-stamp a mismatched
# asset directory.
#
# manifest.sh does no ffmpeg/ffprobe work (pure file copy + text generation),
# so no command stubbing is needed — only a fake `audio/output/aac/` input
# tree, built under a scratch "repo root" so manifest.sh's own
# BASH_SOURCE-derived ROOT_DIR resolves there. A real copy of manifest.sh is
# placed at <root>/audio/manifest.sh for this to work.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_SH="$ROOT_DIR/manifest.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAKE_ROOT="$WORK/repo"
mkdir -p "$FAKE_ROOT/audio"
cp "$MANIFEST_SH" "$FAKE_ROOT/audio/manifest.sh"
chmod +x "$FAKE_ROOT/audio/manifest.sh"

FREQUENCIES=(31 62 125 250 500 1000 2000 4000 8000 16000)
GAINS=(9 6 3 -3 -6 -9)

filename_for() {
  local freq="$1" gain="$2" sign="+"
  [ "$gain" -lt 0 ] && sign="-"
  printf '%05dhz_%s%02ddb.m4a' "$freq" "$sign" "${gain#-}"
}

# Populates $FAKE_ROOT/audio/output/aac with all 60 matrix filenames (empty
# placeholder files — manifest.sh never inspects file contents).
write_full_matrix() {
  rm -rf "$FAKE_ROOT/audio/output"
  mkdir -p "$FAKE_ROOT/audio/output/aac"
  for freq in "${FREQUENCIES[@]}"; do
    for gain in "${GAINS[@]}"; do
      : > "$FAKE_ROOT/audio/output/aac/$(filename_for "$freq" "$gain")"
    done
  done
}

run_scenario() {
  local desc="$1" want_substr="$2"
  local out rc=0
  out="$("$FAKE_ROOT/audio/manifest.sh" 2>&1)" || rc=$?

  if [ -z "$want_substr" ]; then
    if [ "$rc" -ne 0 ]; then
      echo "FAIL [$desc]: expected PASS, got exit $rc. Output: $out" >&2
      exit 1
    fi
  else
    if [ "$rc" -eq 0 ]; then
      echo "FAIL [$desc]: expected non-zero exit, got PASS. Output: $out" >&2
      exit 1
    fi
    if [[ "$out" != *"$want_substr"* ]]; then
      echo "FAIL [$desc]: expected output to contain '$want_substr'. Output: $out" >&2
      exit 1
    fi
  fi
  echo "PASS [$desc]"
}

# Baseline: full, correct 60-file matrix passes every check.
write_full_matrix
run_scenario "baseline fixture (60 correct files) passes every check" ""

# Missing file: manifest.sh always emits all 60 require() lines from its own
# fixed matrix, so removing one input file makes the generated manifest
# reference a file that was never copied into clips/.
write_full_matrix
rm -f "$FAKE_ROOT/audio/output/aac/$(filename_for 31 9)"
run_scenario \
  "missing clip is caught as a dangling manifest entry" \
  "manifest references missing file: 00031hz_+09db.m4a"

# Orphan file: an extra file in the input that isn't part of the fixed
# matrix ends up copied into clips/ but never referenced by any require().
write_full_matrix
: > "$FAKE_ROOT/audio/output/aac/99999hz_+09db.m4a"
run_scenario \
  "extra unmatched clip is caught as an orphan asset" \
  "orphan asset not referenced by manifest: 99999hz_+09db.m4a"

echo "PASS: manifest.sh's AC5/AC6/AC7 self-check catches both missing and orphan clips"
