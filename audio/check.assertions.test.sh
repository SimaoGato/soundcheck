#!/usr/bin/env bash
# Mutation test for check.sh's own core assertion logic (duration, true
# peak, loudness spread, boost/cut-vs-reference, monotonicity, filename
# regex) — the `awk 'BEGIN{ exit !(...) }'` conditions that make up most of
# the file. Without this, a flipped comparison or wrong constant in one of
# those conditions would make check.sh a silent rubber stamp (always PASS)
# and nothing in CI would catch it, since the CI job only ever feeds it
# freshly-generated, presumed-good output. See PR #1 review comment on
# audio/check.sh:94.
#
# Stubs ffmpeg/ffprobe with scripted, controllable output (same technique as
# check.band_ratio_db.test.sh) so each scenario can start from a fixture
# that passes every check, then mutate exactly one measurement and assert
# check.sh fails with the expected message.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SH="$ROOT_DIR/check.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BIN="$WORK/bin"
CLIPS="$WORK/output/wav"
mkdir -p "$BIN" "$CLIPS"
REF="$WORK/output/reference.wav"

CONTROL_FILE="$WORK/control.txt"
export CONTROL_FILE

FILES=(
  "01000hz_+03db.wav"
  "01000hz_+06db.wav"
  "01000hz_+09db.wav"
  "01000hz_-03db.wav"
  "01000hz_-06db.wav"
  "01000hz_-09db.wav"
)
for f in "${FILES[@]}"; do : > "$CLIPS/$f"; done
: > "$REF"

# Stub ffprobe: duration_s() calls `ffprobe ... "$file"`, last arg is the file.
cat > "$BIN/ffprobe" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
file="${@: -1}"
base="$(basename "$file")"
awk -v b="$base" '$1=="DURATION" && $2==b { print $3; found=1 } END { exit !found }' "$CONTROL_FILE"
EOF

# Stub ffmpeg: handles rms_db()'s astats/bandpass+astats filter and
# loudnorm_measure()'s loudnorm filter, both invoked as `-i file -af filter`.
cat > "$BIN/ffmpeg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
file="" filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    -i) file="$2"; shift 2 ;;
    -af) filter="$2"; shift 2 ;;
    *) shift ;;
  esac
done
base="$(basename "$file")"
if [[ "$filter" == loudnorm=* ]]; then
  tp="$(awk -v b="$base" '$1=="TP" && $2==b { print $3; found=1 } END { exit !found }' "$CONTROL_FILE")"
  li="$(awk -v b="$base" '$1=="LI" && $2==b { print $3; found=1 } END { exit !found }' "$CONTROL_FILE")"
  echo "{"
  echo "\"input_i\" : \"$li\","
  echo "\"input_tp\" : \"$tp\","
  echo "}"
elif [[ "$filter" == bandpass=f=* ]]; then
  freq="$(grep -oE 'f=[0-9]+' <<< "$filter" | cut -d= -f2)"
  val="$(awk -v b="$base" -v f="$freq" '$1=="RMSBAND" && $2==b && $3==f { print $4; found=1 } END { exit !found }' "$CONTROL_FILE")"
  echo "[Parsed_astats @ 0x0] RMS level dB: $val"
else
  val="$(awk -v b="$base" '$1=="RMSBB" && $2==b { print $3; found=1 } END { exit !found }' "$CONTROL_FILE")"
  echo "[Parsed_astats @ 0x0] RMS level dB: $val"
fi
EOF
chmod +x "$BIN/ffprobe" "$BIN/ffmpeg"

# Baseline fixture: every file passes every check. Band ratios (band RMS -
# broadband RMS) are 0.00 for the reference and +/-2.00 per +/-3dB step for
# clips, so they satisfy AC5 (boost above / cut below reference) and the
# +3<+6<+9 / -3>-6>-9 monotonicity check at the same time.
write_baseline_control() {
  {
    for f in "${FILES[@]}"; do
      echo "DURATION $f 2.50"
      echo "TP $f -2.0"
      echo "LI $f -18.00"
      echo "RMSBB $f -20.00"
    done
    echo "RMSBAND 01000hz_+03db.wav 1000 -18.00"
    echo "RMSBAND 01000hz_+06db.wav 1000 -16.00"
    echo "RMSBAND 01000hz_+09db.wav 1000 -14.00"
    echo "RMSBAND 01000hz_-03db.wav 1000 -22.00"
    echo "RMSBAND 01000hz_-06db.wav 1000 -24.00"
    echo "RMSBAND 01000hz_-09db.wav 1000 -26.00"
    echo "RMSBB reference.wav -20.00"
    echo "RMSBAND reference.wav 1000 -20.00"
  } > "$CONTROL_FILE"
}

# Args: description, sed-style mutation applied to the control file after
# the baseline is written, expected exit code, substring the FAIL output
# must contain (empty means "must PASS").
run_scenario() {
  local desc="$1" mutate="$2" want_substr="$3"
  write_baseline_control
  if [ -n "$mutate" ]; then
    eval "$mutate"
  fi

  local out rc=0
  out="$(PATH="$BIN:$PATH" "$CHECK_SH" "$CLIPS" wav 2>&1)" || rc=$?

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

run_scenario \
  "baseline fixture passes every check" \
  "" \
  ""

run_scenario \
  "duration outside tolerance is caught" \
  "sed -i 's/^DURATION 01000hz_+03db.wav 2.50\$/DURATION 01000hz_+03db.wav 2.00/' \"\$CONTROL_FILE\"" \
  "duration"

run_scenario \
  "true peak above headroom limit is caught" \
  "sed -i 's/^TP 01000hz_+03db.wav -2.0\$/TP 01000hz_+03db.wav -0.5/' \"\$CONTROL_FILE\"" \
  "true peak"

run_scenario \
  "loudness spread beyond limit is caught" \
  "sed -i 's/^LI 01000hz_+03db.wav -18.00\$/LI 01000hz_+03db.wav -10.00/' \"\$CONTROL_FILE\"" \
  "loudness spread"

run_scenario \
  "boost band ratio not above reference is caught" \
  "sed -i 's/^RMSBAND 01000hz_+03db.wav 1000 -18.00\$/RMSBAND 01000hz_+03db.wav 1000 -20.00/' \"\$CONTROL_FILE\"" \
  "not above reference"

run_scenario \
  "cut band ratio not below reference is caught" \
  "sed -i 's/^RMSBAND 01000hz_-03db.wav 1000 -22.00\$/RMSBAND 01000hz_-03db.wav 1000 -20.00/' \"\$CONTROL_FILE\"" \
  "not below reference"

run_scenario \
  "non-monotonic boost ratios are caught" \
  "sed -i 's/^RMSBAND 01000hz_+09db.wav 1000 -14.00\$/RMSBAND 01000hz_+09db.wav 1000 -17.00/' \"\$CONTROL_FILE\"" \
  "not strictly increasing"

run_scenario \
  "non-monotonic cut ratios are caught" \
  "sed -i 's/^RMSBAND 01000hz_-09db.wav 1000 -26.00\$/RMSBAND 01000hz_-09db.wav 1000 -23.00/' \"\$CONTROL_FILE\"" \
  "not strictly decreasing"

# Filename regex mismatch: rename one clip on disk (not just in the control
# file, since check.sh derives freq/gain from the filename itself). The
# regex mismatch makes check.sh `continue` before it ever touches ffprobe/
# ffmpeg for this file, so no control-file entry for it is needed. Last
# scenario, so the rename is left in place rather than undone.
run_scenario \
  "filename not matching {freq}hz_{sign}{gain}db is caught" \
  "mv \"\$CLIPS/01000hz_+03db.wav\" \"\$CLIPS/bogus.wav\"" \
  "doesn't match"

echo "PASS: check.sh's core assertions (duration, true peak, loudness spread, boost/cut-vs-reference, monotonicity, filename regex) all fail loud on bad input"
