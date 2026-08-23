#!/usr/bin/env bash
# Encodes STORY-01's WAV matrix into mono AAC (.m4a) clips for bundling.
# 64kbps default; 16000Hz ships at 128kbps because refine measured its
# +3dB boost margin over the reference at 64kbps as only 0.48dB — too thin
# to trust across a different ffmpeg build (see STORY-02's Implementation
# Plan "Feasibility confirmed during refine"). Uses ffmpeg's native `aac`
# encoder (the default here) rather than libfdk_aac: Ubuntu's
# `apt-get install ffmpeg`, what CI uses, doesn't ship libfdk_aac (licensing),
# so native AAC is the only encoder actually validated/available in CI —
# don't "upgrade" this to libfdk_aac without re-running the AC4 validation.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/audio/output"
WAV_DIR="$OUT_DIR/wav"
AAC_DIR="$OUT_DIR/aac"

FREQUENCIES=(31 62 125 250 500 1000 2000 4000 8000 16000)
GAINS=(9 6 3 -3 -6 -9)
SAMPLE_RATE=48000

((BASH_VERSINFO[0] >= 4)) || { echo "bash 4+ required (found ${BASH_VERSION}) — on macOS, run: brew install bash && /opt/homebrew/bin/bash $0 $*" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found — install ffmpeg" >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found — install ffmpeg" >&2; exit 1; }

DEFAULT_BITRATE=64k
declare -A BITRATE_OVERRIDE=( [16000]=128k )

# Same filename convention as generate.sh, extension swapped to .m4a.
filename_for() {
  local freq="$1" gain="$2" ext="$3" sign="+"
  [ "$gain" -lt 0 ] && sign="-"
  printf '%05dhz_%s%02ddb.%s' "$freq" "$sign" "${gain#-}" "$ext"
}

bitrate_for() {
  local freq="$1"
  echo "${BITRATE_OVERRIDE[$freq]:-$DEFAULT_BITRATE}"
}

encode_matrix() {
  rm -rf "$AAC_DIR"
  mkdir -p "$AAC_DIR"

  for freq in "${FREQUENCIES[@]}"; do
    local bitrate
    bitrate="$(bitrate_for "$freq")"
    for gain in "${GAINS[@]}"; do
      local wav out
      wav="$WAV_DIR/$(filename_for "$freq" "$gain" wav)"
      out="$AAC_DIR/$(filename_for "$freq" "$gain" m4a)"
      ffmpeg -hide_banner -loglevel error -y -i "$wav" \
        -c:a aac -b:a "$bitrate" -ac 1 -ar "$SAMPLE_RATE" "$out"
    done
  done
}

# AC1: exactly 60 .m4a files, one per WAV source, same (freq, gain) set.
verify_count() {
  local expected=0 actual name failures=()
  for freq in "${FREQUENCIES[@]}"; do
    for gain in "${GAINS[@]}"; do
      expected=$((expected + 1))
      name="$(filename_for "$freq" "$gain" m4a)"
      [ -f "$AAC_DIR/$name" ] || failures+=("missing: $name")
    done
  done
  actual="$(find "$AAC_DIR" -maxdepth 1 -name '*.m4a' | wc -l)"
  [ "$actual" -eq "$expected" ] || failures+=("expected $expected files, found $actual")

  if [ "${#failures[@]}" -gt 0 ]; then
    echo "AC1 FAIL:" >&2
    printf ' - %s\n' "${failures[@]}" >&2
    return 1
  fi
  echo "AC1 PASS: $actual/$expected files present"
}

# AC2 (mono + bitrate only — duration is check.sh's job, run separately
# against this same directory): mono channel count, and stream bit_rate
# within a generous tolerance of the per-frequency target (native AAC isn't
# strict CBR). `stream=bit_rate` is used, not `format=bit_rate`, because the
# format-level figure includes container overhead and reads high for a clip
# this short (measured during refine: 69.2kbps reported for a 64kbps clip).
BITRATE_TOLERANCE=0.20

channels_of() {
  ffprobe -v error -select_streams a:0 -show_entries stream=channels -of default=nk=1:nw=1 "$1"
}

stream_bitrate_of() {
  ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=nk=1:nw=1 "$1"
}

verify_mono_and_bitrate() {
  local failures=()
  for freq in "${FREQUENCIES[@]}"; do
    local bitrate target_bps
    bitrate="$(bitrate_for "$freq")"
    target_bps="${bitrate%k}000"
    for gain in "${GAINS[@]}"; do
      local name file channels bps
      name="$(filename_for "$freq" "$gain" m4a)"
      file="$AAC_DIR/$name"
      channels="$(channels_of "$file")"
      [ "$channels" -eq 1 ] || failures+=("$name: expected mono (1 channel), found $channels")

      bps="$(stream_bitrate_of "$file")"
      if ! awk -v b="$bps" -v t="$target_bps" -v tol="$BITRATE_TOLERANCE" \
          'BEGIN { exit !(b >= t * (1 - tol) && b <= t * (1 + tol)) }'; then
        failures+=("$name: stream bit_rate ${bps}bps outside +/-${BITRATE_TOLERANCE} of target ${target_bps}bps")
      fi
    done
  done

  if [ "${#failures[@]}" -gt 0 ]; then
    echo "AC2 FAIL (mono/bitrate):" >&2
    printf ' - %s\n' "${failures[@]}" >&2
    return 1
  fi
  echo "AC2 PASS: mono + bitrate within tolerance for all files"
}

encode_matrix
verify_count
verify_mono_and_bitrate
