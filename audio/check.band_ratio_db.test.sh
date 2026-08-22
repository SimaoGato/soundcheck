#!/usr/bin/env bash
# Regression test for check.sh's band_ratio_db(): a failing rms_db (e.g.
# grep -oE finds no numeric match on a silent/edge band) must abort the
# script via `set -e`, not silently print a wrong-but-valid number. See the
# PR #1 review comment on audio/check.sh:68-71.
#
# Extracts the real band_ratio_db() definition from check.sh (rather than
# duplicating it here) so this test can't drift from the shipped function.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SH="$ROOT_DIR/check.sh"

fn_src="$(sed -n '/^band_ratio_db() {/,/^}/p' "$CHECK_SH")"
[ -n "$fn_src" ] || { echo "FAIL: couldn't extract band_ratio_db() from check.sh" >&2; exit 1; }

run_in_subshell() {
  # Mimic a silent/edge band: the band-specific rms_db call (freq given)
  # fails with no output, like grep -oE would on a bandpass RMS of -inf,
  # while the broadband call (no freq) succeeds normally. This asymmetry is
  # what let the old string-interpolated awk produce a syntactically valid
  # `print  - -20.00` (unary minus) instead of erroring.
  bash -euo pipefail -c "
    rms_db() { [ -n \"\${2:-}\" ] && return 1; echo '-20.00'; }
    $fn_src
    echo before
    band_ratio_db somefile 1000
    echo 'after: SHOULD NOT PRINT'
  "
}

if output="$(run_in_subshell 2>&1)"; then
  echo "FAIL: band_ratio_db did not abort on a failing rms_db. Output: $output" >&2
  exit 1
fi
if [[ "$output" == *"after: SHOULD NOT PRINT"* ]]; then
  echo "FAIL: band_ratio_db silently continued past a failing rms_db. Output: $output" >&2
  exit 1
fi

echo "PASS: band_ratio_db aborts loudly when rms_db fails"
