#!/usr/bin/env bash
# Verifies generated clips against STORY-01 acceptance criteria AC2-AC6.
# AC1 (file count/naming) and AC7 (determinism) are checked by generate.sh
# instead, since they're specific to the generation step, not something
# STORY-02 reuses when it points this script at encoded output.
#
# Usage: check.sh <dir> <ext>
#   e.g. check.sh audio/output/wav wav
# reference.wav is resolved as dirname(<dir>)/reference.wav — one directory
# level above <dir> (see STORY-01's design decision #6 for the contract this
# depends on).
set -euo pipefail

DIR="${1:?usage: check.sh <dir> <ext>}"
EXT="${2:?usage: check.sh <dir> <ext>}"
REF="$(dirname "$DIR")/reference.wav"

DURATION_TARGET=2.5
DURATION_TOLERANCE=0.05
PEAK_MAX_DB=-1.0
LOUDNESS_SPREAD_MAX_LU=0.5
# One-octave-wide band centred on F, matching generate.sh's equalizer width
# so the check measures exactly the band that was boosted/cut. Must be kept
# equal to generate.sh's WIDTH_TYPE/WIDTH — there is no shared source of
# truth between the two files.
BAND_WIDTH_TYPE=o
BAND_WIDTH=1

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found — install ffmpeg" >&2; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found — install ffmpeg" >&2; exit 1; }
[ -f "$REF" ] || { echo "reference file not found: $REF" >&2; exit 1; }

failures=()

duration_s() {
  ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$1"
}

# Args: file [bandpass_freq]. Prints RMS level in dB, broadband if no freq given.
rms_db() {
  local file="$1" freq="${2:-}" filter="astats=metadata=0"
  [ -n "$freq" ] && filter="bandpass=f=${freq}:width_type=${BAND_WIDTH_TYPE}:width=${BAND_WIDTH},${filter}"
  ffmpeg -hide_banner -nostats -i "$file" -af "$filter" -f null - 2>&1 \
    | grep "RMS level dB" | tail -1 | grep -oE '[-0-9.]+$'
}

# loudnorm's own measurement pass gives both integrated loudness and true
# peak in one JSON blob (input_i, input_tp), so both AC4 and AC6 are read
# from a single ffmpeg invocation instead of two separately-configured ones.
# input_tp is an oversampled/inter-sample true-peak estimate; astats' "Peak
# level dB" is only the sample peak and can under-read true peak by a
# fraction of a dB, so it isn't used for the AC6 assertion.
loudnorm_measure() {
  ffmpeg -hide_banner -nostats -i "$1" -af loudnorm=I=-18:TP=-1.5:LRA=7:print_format=json -f null - 2>&1
}

true_peak_db() {
  grep '"input_tp"' <<< "$1" | grep -oE '\-?[0-9.]+'
}

integrated_loudness() {
  grep '"input_i"' <<< "$1" | grep -oE '\-?[0-9.]+'
}

# Band-to-broadband RMS ratio: gain-invariant, so it isolates the EQ's
# effect from loudnorm's broadband compensation (see story's plan for why
# absolute RMS against the reference doesn't work).
band_ratio_db() {
  local file="$1" freq="$2"
  local band broadband
  band="$(rms_db "$file" "$freq")"
  broadband="$(rms_db "$file")"
  awk -v b="$band" -v bb="$broadband" 'BEGIN { print b - bb }'
}

shopt -s nullglob
files=("$DIR"/*."$EXT")
shopt -u nullglob
if [ "${#files[@]}" -eq 0 ]; then
  echo "no *.$EXT files found in $DIR" >&2
  exit 1
fi

declare -A ratio_of        # key "freq_gain" -> band ratio dB
declare -A ref_ratio_of    # key freq -> reference band ratio dB
freqs_seen=()
min_loudness=""
max_loudness=""

for file in "${files[@]}"; do
  name="$(basename "$file")"

  if [[ ! "$name" =~ ^([0-9]{5})hz_([+-])([0-9]{2})db\.${EXT}$ ]]; then
    failures+=("$name: filename doesn't match {freq:05d}hz_{sign}{gain:02d}db.$EXT")
    continue
  fi
  freq="$((10#${BASH_REMATCH[1]}))"
  sign="${BASH_REMATCH[2]}"
  gain="$((10#${BASH_REMATCH[3]}))"
  [ "$sign" = "-" ] && gain=$((-gain))

  # AC5: duration
  dur="$(duration_s "$file")"
  if ! awk -v d="$dur" -v t="$DURATION_TARGET" -v tol="$DURATION_TOLERANCE" \
      'BEGIN { exit !(d >= t - tol && d <= t + tol) }'; then
    failures+=("$name: duration ${dur}s outside ${DURATION_TARGET}s +/- ${DURATION_TOLERANCE}s")
  fi

  # AC4/AC6 share one loudnorm measurement pass per file.
  measure="$(loudnorm_measure "$file")"

  # AC6: true peak headroom
  peak="$(true_peak_db "$measure")"
  if ! awk -v p="$peak" -v max="$PEAK_MAX_DB" 'BEGIN { exit !(p <= max) }'; then
    failures+=("$name: true peak ${peak}dB exceeds ${PEAK_MAX_DB}dB headroom limit")
  fi

  # AC4: collect integrated loudness, spread checked after the loop
  loud="$(integrated_loudness "$measure")"
  if [ -z "$min_loudness" ] || awk -v l="$loud" -v m="$min_loudness" 'BEGIN { exit !(l < m) }'; then
    min_loudness="$loud"
  fi
  if [ -z "$max_loudness" ] || awk -v l="$loud" -v m="$max_loudness" 'BEGIN { exit !(l > m) }'; then
    max_loudness="$loud"
  fi

  # AC2/AC3: band-to-broadband ratio vs. reference, collected for the
  # cross-file (vs.-reference and monotonicity) checks after the loop.
  ratio="$(band_ratio_db "$file" "$freq")"
  ratio_of["${freq}_${gain}"]="$ratio"
  if [[ ! " ${freqs_seen[*]:-} " == *" $freq "* ]]; then
    freqs_seen+=("$freq")
  fi
  if [ -z "${ref_ratio_of[$freq]:-}" ]; then
    ref_ratio_of[$freq]="$(band_ratio_db "$REF" "$freq")"
  fi

  if [ "$gain" -gt 0 ]; then
    if ! awk -v r="$ratio" -v ref="${ref_ratio_of[$freq]}" 'BEGIN { exit !(r > ref) }'; then
      failures+=("$name: boost band ratio ${ratio}dB not above reference ${ref_ratio_of[$freq]}dB")
    fi
  else
    if ! awk -v r="$ratio" -v ref="${ref_ratio_of[$freq]}" 'BEGIN { exit !(r < ref) }'; then
      failures+=("$name: cut band ratio ${ratio}dB not below reference ${ref_ratio_of[$freq]}dB")
    fi
  fi
done

# AC4: loudness spread across the whole set
if [ -n "$min_loudness" ]; then
  spread="$(awk -v mn="$min_loudness" -v mx="$max_loudness" 'BEGIN { print mx - mn }')"
  if ! awk -v s="$spread" -v max="$LOUDNESS_SPREAD_MAX_LU" 'BEGIN { exit !(s <= max) }'; then
    failures+=("loudness spread ${spread}LU exceeds ${LOUDNESS_SPREAD_MAX_LU}LU (min=${min_loudness} max=${max_loudness})")
  fi
fi

# AC2/AC3: monotonic across +3->+6->+9 and -3->-6->-9, per frequency
for freq in "${freqs_seen[@]}"; do
  r3="${ratio_of[${freq}_3]:-}"
  r6="${ratio_of[${freq}_6]:-}"
  r9="${ratio_of[${freq}_9]:-}"
  if [ -n "$r3" ] && [ -n "$r6" ] && [ -n "$r9" ]; then
    if ! awk -v a="$r3" -v b="$r6" -v c="$r9" 'BEGIN { exit !(a < b && b < c) }'; then
      failures+=("${freq}Hz boost: ratios not strictly increasing +3=${r3} +6=${r6} +9=${r9}")
    fi
  fi
  rn3="${ratio_of[${freq}_-3]:-}"
  rn6="${ratio_of[${freq}_-6]:-}"
  rn9="${ratio_of[${freq}_-9]:-}"
  if [ -n "$rn3" ] && [ -n "$rn6" ] && [ -n "$rn9" ]; then
    if ! awk -v a="$rn3" -v b="$rn6" -v c="$rn9" 'BEGIN { exit !(a > b && b > c) }'; then
      failures+=("${freq}Hz cut: ratios not strictly decreasing -3=${rn3} -6=${rn6} -9=${rn9}")
    fi
  fi
done

if [ "${#failures[@]}" -gt 0 ]; then
  echo "FAIL: ${#failures[@]} check(s) failed:" >&2
  printf ' - %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "PASS: all checks green for ${#files[@]} file(s) in $DIR"
