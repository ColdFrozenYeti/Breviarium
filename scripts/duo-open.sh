#!/usr/bin/env bash
# Opens a booted iPhone Duo simulator flat and turns it (1.7), for App CI's Duo passes
# (scripts/ci-simulator.sh) and promo.yml's Duo stills.
#
#   scripts/duo-open.sh <udid> portrait|landscape
#
# The Duo boots folded, showing its outer screen (1398 x 2034 px); open, its inner screen
# is 669 x 951 pt upright and 951 x 669 on its side. simctl has no fold command, so
# duoctl (MIT, skarol/duoctl, pinned below; CI tooling only, nothing of it is in the app)
# opens and turns it through a helper it builds and spawns in the simulator. It uses
# private interfaces and may break with a later Xcode: then this warns, leaves the Duo
# folded and exits 0, so nothing else fails. Under GitHub Actions it writes `opened=1`
# to the step's output only once `duoctl state` shows the inner screen in the orientation
# asked for (`opened=0` otherwise), so a caller can skip what needs the open Duo. Set BREVIARIUM_DUO_OPEN=0 to skip it; to
# remove it, delete this file and its two callers' lines (approved by the user,
# 2026-11-17).
set -uo pipefail

udid="$1"
rotation="${2:-portrait}"
[ "${BREVIARIUM_DUO_OPEN:-1}" = 1 ] || { echo "duo-open: skipped (BREVIARIUM_DUO_OPEN=0)" >&2; exit 0; }

duoctl_commit=c6ff3e961a9858fb061907448e702d7d1617dc4a  # v0.2.1, Xcode 27.2 support
duoctl_dir="${RUNNER_TEMP:-/tmp}/duoctl"
duoctl="$duoctl_dir/skills/duoctl/scripts/duoctl"
duo() { DUOCTL_UDID="$udid" python3 "$duoctl" "$@"; }

result() { [ -n "${GITHUB_OUTPUT:-}" ] && echo "opened=$1" >> "$GITHUB_OUTPUT"; return 0; }
warn() { echo "::warning::duo-open: $1; the iPhone Duo stays as it is (folded unless opened before)." >&2; result 0; exit 0; }

if [ ! -x "$duoctl" ]; then
  { git clone --quiet https://github.com/skarol/duoctl.git "$duoctl_dir" \
      && git -C "$duoctl_dir" checkout --quiet "$duoctl_commit"; } >&2 || warn "couldn't fetch duoctl"
fi

# A Duo booted by simctl alone had no active display for devicectl (duoctl: "no display
# is active") until an app had run on it, so a system app is launched first; then up to
# three minutes for the display.
xcrun simctl launch "$udid" com.apple.Preferences > /dev/null 2>&1 || true
ready=0
for _ in $(seq 18); do
  if duo state > /dev/null 2>&1; then ready=1; break; fi
  sleep 10
done
[ "$ready" = 1 ] || warn "no active display after three minutes"
xcrun simctl terminate "$udid" com.apple.Preferences > /dev/null 2>&1 || true

duo open >&2 || warn "duoctl open failed"
duo rotate "$rotation" >&2 || warn "duoctl rotate $rotation failed"
# Checked, not assumed: the inner screen, turned as asked.
state=$(duo state 2> /dev/null) || warn "duoctl state failed after opening"
echo "$state" >&2
echo "$state" | ROTATION="$rotation" python3 -c '
import json, os, sys
s = json.load(sys.stdin)
w, h = s.get("sizePoints", [0, 0])
want = os.environ["ROTATION"]
ok = s.get("activeScreen") == "inner" and min(w, h) > 600 and s.get("orientation") == want and ((w > h) == (want == "landscape"))
sys.exit(0 if ok else 1)' || warn "the Duo isn't open $rotation after duoctl"
echo "iPhone Duo opened ($rotation)." >&2
result 1
