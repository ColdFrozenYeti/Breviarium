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

## Docker (needed for M4's oracle-fixture generation)

Attempted via `winget install --id Docker.DockerDesktop` during M4 — got further than
expected but hit a hard wall that needs your hands:

1. **WSL2 isn't installed.** `wsl --install` needs to enable Windows optional features
   (Virtual Machine Platform, Windows Subsystem for Linux), which needs an elevated
   session and normally a **restart**. Run from an **Administrator** PowerShell:
   ```
   wsl --install
   ```
   then restart when it asks. (If it asks you to set a WSL username/password on first
   boot after the restart, any values are fine — Docker Desktop doesn't need you to use
   that Linux user directly.)

2. **The Docker Desktop installer itself also needs an interactive admin approval** — it
   pops a UAC prompt ("Docker Desktop Installer.exe wants to make changes to your
   device") that only completes with a human clicking "Yes" at the machine. Run:
   ```
   winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
   ```
   and click through the UAC prompt when it appears, then follow Docker Desktop's own
   first-run setup (it'll ask to use the WSL2 backend — say yes) and accept its licence
   terms (free for personal use, which this is).

Both of these are genuine "must be a human clicking a Windows security prompt" steps —
not something safe or possible to script around from an unattended session, the same way
the Windows SDK component in the section above needed an elevated terminal. Once done,
`docker --version` and `docker run hello-world` should both work, and
`scripts/generate-oracle-fixtures.*` can run against the pinned DO checkout
(`data/SOURCE.md`, `scripts/docker/docker-compose.yml`).

## Status

**Confirmed working as of 2026-09-16.** `.\scripts\test-kit.ps1` builds and runs the full
Kit test suite locally (121 tests, matching `kit-ci.yml`'s count exactly). Getting here
took three separate fixes, kept here in case any recur after a future reinstall:

1. The Windows 11 SDK component (§2 above) — needed an elevated install.
2. `vcvars64.bat`'s own internals shell out to `vswhere.exe`, but the VS Installer never
   adds its own folder to the registered PATH — `test-kit.ps1` now adds it itself.
3. **The actual final blocker: a corrupted/incomplete Swift toolchain install**, not a
   configuration issue. `swiftc` failed with "unable to load standard library for target
   'x86_64-unknown-windows-msvc'" even with `vcvars64` correctly loaded (LIB/INCLUDE
   verified pointing at the right SDK/MSVC paths) — tracked down to the Windows platform
   SDK under `%LOCALAPPDATA%\Programs\Swift\Platforms\<version>\Windows.platform\...\
   Windows.sdk\usr\lib\swift\windows\x86_64` having every compiled `.lib` file but **no
   `.swiftmodule` files at all**, anywhere in the install — meaning `import Swift`
   (implicit in every Swift file) could never resolve. Fixed by a clean reinstall:
   `winget uninstall --id Swift.Toolchain`, deleting any leftover
   `%LOCALAPPDATA%\Programs\Swift` folder, then `winget install --id Swift.Toolchain`
   fresh.

A separate, unrelated issue hit along the way: having two toolchain versions installed
side by side (e.g. a leftover 6.3.3 alongside a newer 6.4.0) makes `swift build` refuse
to run entirely ("platform 'windows' already registered") — `swift build`'s platform
discovery scans every version folder under `Programs\Swift`, not just whichever is on
PATH, so the fix is deleting the old version's `Toolchains`/`Runtimes`/`Platforms`
folders outright, not just reordering PATH.
