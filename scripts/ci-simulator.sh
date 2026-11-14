#!/usr/bin/env bash
# Picks an iOS 26 simulator for App CI's UI tests, makes one if the runner has none,
# boots it and waits for it, and prints its UDID.
#
#   scripts/ci-simulator.sh iphone   # an iPhone 17, else any iPhone
#   scripts/ci-simulator.sh ipad     # an iPad Air 11-inch (M3), the iPad App Review used
#                                    # (1.4), else any iPad Air, else any iPad
#
# Run 197 (12 November 2026): one runner had no iPhone 17 and xcodebuild found no
# destination. A cold boot during the first launch once timed out and left xcodebuild
# waiting for good, so the simulator is booted here first.
set -euo pipefail

kind="${1:-iphone}"
case "$kind" in
  iphone) name="iPhone 17"; prefixes="iPhone"; type="com.apple.CoreSimulator.SimDeviceType.iPhone-17" ;;
  ipad) name="iPad Air 11-inch (M3)"; prefixes="iPad Air|iPad"; type="com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M3" ;;
  *) echo "usage: $0 iphone|ipad" >&2; exit 2 ;;
esac

udid=$(xcrun simctl list devices available -j | NAME="$name" PREFIXES="$prefixes" python3 -c '
import json, os, sys
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS-26" in runtime for d in ds]
match = [d for d in devices if d["name"] == os.environ["NAME"]]
for prefix in os.environ["PREFIXES"].split("|"):
    match = match or [d for d in devices if d["name"].startswith(prefix)]
print(match[0]["udid"] if match else "")')

if [ -z "$udid" ]; then
  runtime=$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-26")]
print(rs[-1]["identifier"] if rs else "")')
  if [ -z "$runtime" ]; then
    echo "No iOS 26 simulator runtime on this runner." >&2
    xcrun simctl list runtimes >&2
    exit 1
  fi
  udid=$(xcrun simctl create "$name" "$type" "$runtime")
fi

echo "Simulator ($kind): $udid" >&2
xcrun simctl boot "$udid" >&2 || true
xcrun simctl bootstatus "$udid" -b >&2
echo "$udid"
