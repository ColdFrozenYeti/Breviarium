# Local Swift toolchain setup (Windows)

One-time setup to get `swift build` / `swift test` working for `BreviariumKit` on this
machine. `scripts/test-kit.ps1` handles the PATH/environment wiring every time after this
is done once.

## 1. Install the Swift toolchain

```
winget install --id Swift.Toolchain
```

This installs Swift 6.3.3 (or later) to `%LOCALAPPDATA%\Programs\Swift`. A new terminal
picks up the updated PATH automatically; `scripts/test-kit.ps1` refreshes it itself if
you're in an already-open shell.

## 2. Install the MSVC linker *and* a Windows SDK

Swift on Windows links through MSVC's `link.exe`, which in turn needs the Windows SDK's
import libraries (`kernel32.lib`, etc.) — the C++ build tools alone are **not** enough.

If you don't have Visual Studio or Build Tools installed at all:

```
winget install --id Microsoft.VisualStudio.2022.BuildTools --override "--quiet --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621"
```

If Build Tools is already installed (as it was on this machine) but `swift build` fails
with `could not find CLI tool 'link'` or, after adding the C++ workload, with `unable to
load standard library for target 'x86_64-unknown-windows-msvc'` — that second error
specifically means the C++ tools are present but the Windows SDK component isn't. Check
whether `C:\Program Files (x86)\Windows Kits\10` exists; if it doesn't, add the SDK
component to the existing install:

```
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --quiet --norestart
```

**This must be run from an elevated (Administrator) terminal.** Run non-elevated, the
installer exits immediately with "Commands with --quiet or --passive should be run
elevated from the beginning" (exit code 5007) and does nothing — which is what happened
when this was attempted from an unprivileged automated shell during M0. Open PowerShell
"as Administrator" (right-click → Run as administrator) and run the command above there.

## 3. Verify

```
.\scripts\test-kit.ps1
```

This should print `swift build` and `swift test` output ending in a passing test summary.
If `link.exe` still can't be found, confirm it exists at (version number will vary):

```
C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\<version>\bin\Hostx64\x64\link.exe
```

## Status as of M0

Swift 6.3.3 and VS Build Tools 2022 (with the `VC.Tools.x86.x64` component) were
installed, but the Windows 11 SDK component was missing and its installation needs the
elevated step above — this was the one piece of M0 that needed manual action on this
machine rather than being fully automatable. Once step 2 is done, `swift build`/`swift
test` should be verified to pass before M1 begins in earnest, since M2 onward depends on
the Kit actually building.
