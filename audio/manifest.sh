#!/usr/bin/env bash
# Publishes STORY-02's encoded AAC clips as committed app assets and
# generates a TypeScript manifest keyed by (frequency, gain). This is the
# one place in this story where generated output is committed rather than
# git-ignored — see STORY-02's Implementation Plan design decision 3: unlike
# audio/output/, these are the actual shipped assets and need to exist
# without regeneration (or ffmpeg) for a plain app build/EAS Build.
#
# Assumes audio/output/aac/*.m4a already passed check.sh (encode.sh + check.sh
# run before this in CI/locally) — this script only copies bytes, it does not
# re-verify AC2/AC4 against the published copy since the copy is byte-for-
# byte identical to what check.sh already validated.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AAC_DIR="$ROOT_DIR/audio/output/aac"
ASSETS_DIR="$ROOT_DIR/assets/audio"
CLIPS_DIR="$ASSETS_DIR/clips"
MANIFEST="$ASSETS_DIR/manifest.ts"

FREQUENCIES=(31 62 125 250 500 1000 2000 4000 8000 16000)
GAINS=(9 6 3 -3 -6 -9)
CEILING_BYTES=2000000
PRD_TARGET_BYTES=1258291 # ~1.2MB, informational only (logged, not asserted)

((BASH_VERSINFO[0] >= 4)) || { echo "bash 4+ required (found ${BASH_VERSION})" >&2; exit 1; }

filename_for() {
  local freq="$1" gain="$2" ext="$3" sign="+"
  [ "$gain" -lt 0 ] && sign="-"
  printf '%05dhz_%s%02ddb.%s' "$freq" "$sign" "${gain#-}" "$ext"
}

publish_clips() {
  [ -d "$AAC_DIR" ] || { echo "$AAC_DIR not found — run encode.sh first" >&2; exit 1; }
  rm -rf "$ASSETS_DIR"
  mkdir -p "$CLIPS_DIR"
  cp "$AAC_DIR"/*.m4a "$CLIPS_DIR"/
}

# AC3: total published size within the hard ceiling, PRD figure logged for
# reference only (see design decision 5 — the PRD's ~1.2MB is a target, not
# an assertion; CEILING_BYTES is the actual gate).
verify_size() {
  local total
  total="$(du -cb "$CLIPS_DIR"/*.m4a | tail -1 | cut -f1)"
  echo "AC3: total size ${total} bytes (PRD target ~${PRD_TARGET_BYTES} bytes, ceiling ${CEILING_BYTES} bytes)"
  if [ "$total" -gt "$CEILING_BYTES" ]; then
    echo "AC3 FAIL: ${total} bytes exceeds ceiling of ${CEILING_BYTES} bytes" >&2
    return 1
  fi
  echo "AC3 PASS: ${total} bytes within ${CEILING_BYTES} byte ceiling"
}

# Generates the TypeScript manifest: one literal require() per clip (Metro
# can only bundle static, literal require() paths — see design decision 1),
# a Record<ClipKey, number> so a future tsc run rejects a missing/extra key,
# and a single getClip() lookup for playback code (EPIC-02) to call.
generate_manifest() {
  {
    echo "// GENERATED FILE — do not hand-edit. Regenerate via \`audio/manifest.sh\`."
    echo "export const FREQUENCIES = [$(IFS=,; echo "${FREQUENCIES[*]}")] as const;"
    echo "export type Frequency = (typeof FREQUENCIES)[number];"
    echo
    echo "export const GAINS = [$(IFS=,; echo "${GAINS[*]}")] as const;"
    echo "export type Gain = (typeof GAINS)[number];"
    echo
    echo "type ClipKey = \`\${Frequency}_\${Gain}\`;"
    echo
    echo "export const CLIPS: Record<ClipKey, number> = {"
    for freq in "${FREQUENCIES[@]}"; do
      for gain in "${GAINS[@]}"; do
        echo "  \"${freq}_${gain}\": require('./clips/$(filename_for "$freq" "$gain" m4a)'),"
      done
    done
    echo "};"
    echo
    echo "export function getClip(frequency: Frequency, gain: Gain): number {"
    echo "  return CLIPS[\`\${frequency}_\${gain}\` as ClipKey];"
    echo "}"
  } > "$MANIFEST"
}

# AC5/AC6/AC7 self-check, re-deriving the expected file list from the same
# 10x6 loop rather than loading manifest.ts (Node can't require() a .m4a):
#   AC5: exactly 60 literal require() lines, each resolving to a real file.
#   AC6: no orphan clip file absent from the manifest, no dangling manifest
#        entry with no file (both directions).
#   AC7: every entry is a literal require('./clips/...') string (not a
#        dynamically constructed path) — enforced by the grep pattern itself
#        rejecting anything else.
verify_manifest() {
  local failures=() require_lines referenced=() actual_files=() f base

  require_lines="$(grep -oE "require\('\./clips/[0-9]{5}hz_[+-][0-9]{2}db\.m4a'\)" "$MANIFEST" || true)"
  local count
  count="$(echo -n "$require_lines" | grep -c "require(" || true)"
  [ "$count" -eq 60 ] || failures+=("expected 60 literal require() entries, found $count")

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    base="$(grep -oE '[0-9]{5}hz_[+-][0-9]{2}db\.m4a' <<< "$line")"
    referenced+=("$base")
    [ -f "$CLIPS_DIR/$base" ] || failures+=("manifest references missing file: $base")
  done <<< "$require_lines"

  shopt -s nullglob
  for f in "$CLIPS_DIR"/*.m4a; do
    base="$(basename "$f")"
    actual_files+=("$base")
    if [[ ! " ${referenced[*]:-} " == *" $base "* ]]; then
      failures+=("orphan asset not referenced by manifest: $base")
    fi
  done
  shopt -u nullglob

  if [ "${#failures[@]}" -gt 0 ]; then
    echo "AC5/AC6/AC7 FAIL:" >&2
    printf ' - %s\n' "${failures[@]}" >&2
    return 1
  fi
  echo "AC5/AC6/AC7 PASS: 60 literal require() entries, all resolve, no orphans"
}

publish_clips
verify_size
generate_manifest
verify_manifest
