#!/usr/bin/env bash
# Picks an iOS 27 simulator for App CI's UI tests, makes one if the runner has none,
# boots it and waits for it, and prints its UDID.
#
#   scripts/ci-simulator.sh iphone   # an iPhone 17, else any iPhone
#   scripts/ci-simulator.sh ipad     # an iPad Air 11-inch (M4), else any iPad Air, else
#                                    # any iPad (App Review used an M3 in 1.4; the iOS 27.2
#                                    # runtime has only the M4, the same 820 x 1180 pt)
#   scripts/ci-simulator.sh duo      # an iPhone Duo (1.7)
#
# Since 1.7 the app is built with the iOS 27 SDK (Xcode 27.2), whose runtimes are iOS 27.x:
# the newest runtime that has the device wins, as 27.1 has only the iPhone Duo.
#
# Run 197 (12 November 2026): one runner had no iPhone 17 and xcodebuild found no
# destination. A cold boot during the first launch once timed out and left xcodebuild
# waiting for good, so the simulator is booted here first.
set -euo pipefail

kind="${1:-iphone}"
case "$kind" in
  iphone) name="iPhone 17"; prefixes="iPhone"; type="com.apple.CoreSimulator.SimDeviceType.iPhone-17" ;;
  ipad) name="iPad Air 11-inch (M4)"; prefixes="iPad Air|iPad"; type="com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4" ;;
  duo|duo-side) name="iPhone Duo"; prefixes="iPhone Duo"; type="com.apple.CoreSimulator.SimDeviceType.iPhone-Duo" ;;
  *) echo "usage: $0 iphone|ipad|duo|duo-side" >&2; exit 2 ;;
esac

udid=$(xcrun simctl list devices available -j | NAME="$name" PREFIXES="$prefixes" python3 -c '
import json, os, sys
runtimes = json.load(sys.stdin)["devices"]
devices = [d for r in sorted((r for r in runtimes if "iOS-27" in r), reverse=True) for d in runtimes[r]]
match = [d for d in devices if d["name"] == os.environ["NAME"]]
for prefix in os.environ["PREFIXES"].split("|"):
    match = match or [d for d in devices if d["name"].startswith(prefix)]
print(match[0]["udid"] if match else "")')

if [ -z "$udid" ]; then
  # The newest iOS 27 runtime; the device type is looked up by name, falling back to the
  # identifier guessed above.
  runtime=$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-27")]
print(rs[-1]["identifier"] if rs else "")')
  if [ -z "$runtime" ]; then
    echo "No iOS 27 simulator runtime on this runner." >&2
    xcrun simctl list runtimes >&2
    exit 1
  fi
  found=$(xcrun simctl list devicetypes -j | NAME="$name" python3 -c '
import json, os, sys
ts = [t for t in json.load(sys.stdin)["devicetypes"] if t["name"] == os.environ["NAME"]]
print(ts[0]["identifier"] if ts else "")')
  udid=$(xcrun simctl create "$name" "${found:-$type}" "$runtime")
fi

echo "Simulator ($kind): $udid" >&2
xcrun simctl boot "$udid" >&2 || true
xcrun simctl bootstatus "$udid" -b >&2

# 1.7: the iPhone Duo boots folded; opened flat and turned with duoctl
# (scripts/duo-open.sh): upright for `duo`, on its side for `duo-side`. XCUIDevice can't
# turn the open Duo, nor can XCUITest's swipes reach its inner screen.
case "$kind" in
  duo) "$(dirname "$0")/duo-open.sh" "$udid" portrait ;;
  duo-side) "$(dirname "$0")/duo-open.sh" "$udid" landscape ;;
esac
echo "$udid"
