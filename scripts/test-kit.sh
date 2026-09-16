#!/usr/bin/env bash
# Builds and tests BreviariumKit with the open-source Swift toolchain.
# Works on Linux and macOS out of the box; on Windows use test-kit.ps1 instead
# (swiftc's own PATH/DLL requirements need proper Windows environment handling
# that a Git Bash shell can't reliably provide).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../Packages/BreviariumKit"

echo "==> swift build"
swift build

echo "==> swift test"
swift test
