#!/usr/bin/env bash
# Generates the pink-noise EQ clip matrix: 10 frequencies x 6 gains = 60
# clips, one octave-wide band boosted or cut per clip, plus an unprocessed
# reference used only for check.sh's band-energy comparison.
#
# Validated against ffmpeg 7.0.x (static build); a different ffmpeg version
# could in principle produce different seeded noise output, breaking
# reproducibility (AC7) across machines.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/audio/output"
WAV_DIR="$OUT_DIR/wav"
REF_FILE="$OUT_DIR/reference.wav"

FREQUENCIES=(31 62 125 250 500 1000 2000 4000 8000 16000)
GAINS=(9 6 3 -3 -6 -9)
SAMPLE_RATE=48000
DURATION=2.5
SEED=42
# One octave wide, constant across all bands, so difficulty is set by gain
# alone (per the story's technical notes).
WIDTH_TYPE=o
WIDTH=1
LOUDNORM="loudnorm=I=-18:TP=-1.5:LRA=7:linear=true"

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found — install ffmpeg" >&2; exit 1; }

# AC1's filename convention: {freq:05d}hz_{sign}{gain:02d}db.wav.
filename_for() {
  local freq="$1" gain="$2" sign="+"
  [ "$gain" -lt 0 ] && sign="-"
  printf '%05dhz_%s%02ddb.wav' "$freq" "$sign" "${gain#-}"
}

generate_matrix() {
  rm -rf "$OUT_DIR"
  mkdir -p "$WAV_DIR"

  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "anoisesrc=color=pink:seed=${SEED}:duration=${DURATION}:sample_rate=${SAMPLE_RATE}" \
    -ac 1 -ar "$SAMPLE_RATE" "$REF_FILE"

  for freq in "${FREQUENCIES[@]}"; do
    for gain in "${GAINS[@]}"; do
      out="$WAV_DIR/$(filename_for "$freq" "$gain")"
      ffmpeg -hide_banner -loglevel error -y -i "$REF_FILE" \
        -af "equalizer=f=${freq}:width_type=${WIDTH_TYPE}:width=${WIDTH}:g=${gain},${LOUDNORM}" \
        -ac 1 -ar "$SAMPLE_RATE" "$out"
    done
  done
}

# AC1: exactly 60 files, one per (frequency, gain) combo, none missing/extra.
verify_matrix() {
  local expected=0 actual name failures=()
  for freq in "${FREQUENCIES[@]}"; do
    for gain in "${GAINS[@]}"; do
      expected=$((expected + 1))
      name="$(filename_for "$freq" "$gain")"
      [ -f "$WAV_DIR/$name" ] || failures+=("missing: $name")
    done
  done
  actual="$(find "$WAV_DIR" -maxdepth 1 -name '*.wav' | wc -l)"
  [ "$actual" -eq "$expected" ] || failures+=("expected $expected files, found $actual")

  if [ "${#failures[@]}" -gt 0 ]; then
    echo "AC1 FAIL:" >&2
    printf ' - %s\n' "${failures[@]}" >&2
    return 1
  fi
  echo "AC1 PASS: $actual/$expected files present"
}

# AC7: two clean-state runs must produce byte-identical output.
verify_determinism() {
  local first second
  generate_matrix
  first="$(cd "$WAV_DIR" && sha256sum -- *.wav | sort)"
  generate_matrix
  second="$(cd "$WAV_DIR" && sha256sum -- *.wav | sort)"
  if [ "$first" != "$second" ]; then
    echo "AC7 FAIL: checksums differ between two clean-state runs" >&2
    diff <(echo "$first") <(echo "$second") >&2
    return 1
  fi
  echo "AC7 PASS: checksums identical across two clean-state runs"
}

if [ "${1:-}" = "--verify" ]; then
  verify_determinism
  verify_matrix
else
  generate_matrix
  verify_matrix
fi
