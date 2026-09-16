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

$swiftProgramsDir = "$env:LOCALAPPDATA\Programs\Swift"
$toolchainsDir = Join-Path $swiftProgramsDir "Toolchains"
if (Test-Path $toolchainsDir) {
    # If more than one toolchain version is installed side by side, prefer the newest -
    # an older one can be a broken/incomplete leftover (seen on this machine: the 6.3.3
    # toolchain crashes with STATUS_DLL_NOT_FOUND, exit code 53, while a newer 6.4.0
    # install works fine) even though both are still registered on PATH.
    $newestToolchain = Get-ChildItem $toolchainsDir -Directory |
        Sort-Object { [version]($_.Name -replace '\+.*$', '') } -Descending |
        Select-Object -First 1
    if ($newestToolchain) {
        $version = $newestToolchain.Name -replace '\+.*$', ''
        $env:Path = (Join-Path $newestToolchain.FullName "usr\bin") + ";" + $env:Path
        $runtimeBin = Join-Path $swiftProgramsDir "Runtimes\$version\usr\bin"
        if (Test-Path $runtimeBin) { $env:Path = "$runtimeBin;" + $env:Path }
    }
}

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    Write-Error "swift not found on PATH. Install it with: winget install --id Swift.Toolchain"
    exit 1
}

& swift --version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "swift --version failed (exit $LASTEXITCODE) even after preferring the newest installed toolchain. A toolchain install may be broken - see docs/windows-swift-setup.md."
    exit 1
}

$vswhereDir = "C:\Program Files (x86)\Microsoft Visual Studio\Installer"
if ((Test-Path $vswhereDir) -and ($env:Path -notlike "*$vswhereDir*")) {
    # vcvars64.bat's own internals shell out to vswhere.exe, but the VS Installer never
    # adds its own folder to the registered machine/user PATH - so without this, vcvars64
    # fails with "'vswhere.exe' is not recognized" even though Build Tools is installed.
    $env:Path = "$vswhereDir;$env:Path"
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
