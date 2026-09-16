# Builds and tests BreviariumKit with the open-source Swift toolchain on Windows.
#
# Requires: the Swift toolchain (winget install Swift.Toolchain) and, for the linker,
# Visual Studio Build Tools 2022 with the "Desktop development with C++" workload AND
# a Windows SDK component (Microsoft.VisualStudio.Component.Windows11SDK.<version>) -
# the VC.Tools component alone is not enough. See docs/windows-swift-setup.md.
#
# A freshly opened shell often doesn't have swift.exe on PATH yet because winget updates
# the machine/user PATH in the registry, not the current process's environment - this
# script refreshes PATH from the registry itself so `./scripts/test-kit.ps1` works
# without needing a new terminal.

$ErrorActionPreference = "Stop"

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Write-Error "swift not found on PATH. Install it with: winget install --id Swift.Toolchain"
    exit 1
}

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if (Test-Path $vcvars) {
    $vcvarsOutput = cmd /c "`"$vcvars`" && set"
    foreach ($line in $vcvarsOutput) {
        if ($line -match '^([^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
} else {
    Write-Warning "vcvars64.bat not found at the expected Build Tools path - swift build's linker step will likely fail without it. See docs/windows-swift-setup.md."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $repoRoot "Packages\BreviariumKit")

Write-Host "==> swift build"
swift build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> swift test"
swift test
exit $LASTEXITCODE
