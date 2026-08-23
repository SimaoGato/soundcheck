#!/usr/bin/env bash
# Regression test: generate.sh's WIDTH_TYPE/WIDTH (the band actually
# boosted/cut) must stay equal to check.sh's BAND_WIDTH_TYPE/BAND_WIDTH (the
# band check.sh measures). There is no shared source of truth between the
# two files — only a paired comment — so a divergence would make check.sh
# silently measure a different band than the one generate.sh touched and
# still print PASS. See PR #1 review comment on audio/generate.sh:21-26.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE_SH="$ROOT_DIR/generate.sh"
CHECK_SH="$ROOT_DIR/check.sh"

extract() {
  # Args: file, var name. Errors loudly if the assignment isn't found rather
  # than comparing two empty strings and passing by accident.
  local file="$1" var="$2" value
  value="$(grep -oE "^${var}=[^ ]+" "$file" | head -1 | cut -d= -f2)"
  [ -n "$value" ] || { echo "FAIL: couldn't find ${var}= in $file" >&2; exit 1; }
  echo "$value"
}

gen_width_type="$(extract "$GENERATE_SH" WIDTH_TYPE)"
gen_width="$(extract "$GENERATE_SH" WIDTH)"
check_width_type="$(extract "$CHECK_SH" BAND_WIDTH_TYPE)"
check_width="$(extract "$CHECK_SH" BAND_WIDTH)"

failures=()
[ "$gen_width_type" = "$check_width_type" ] || failures+=("generate.sh WIDTH_TYPE=$gen_width_type != check.sh BAND_WIDTH_TYPE=$check_width_type")
[ "$gen_width" = "$check_width" ] || failures+=("generate.sh WIDTH=$gen_width != check.sh BAND_WIDTH=$check_width")

if [ "${#failures[@]}" -gt 0 ]; then
  echo "FAIL: generate.sh and check.sh band width settings diverged:" >&2
  printf ' - %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "PASS: generate.sh and check.sh agree on band width (type=$gen_width_type width=$gen_width)"
