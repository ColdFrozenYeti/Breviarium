# Downloads the latest successful build-ipa.yml artifact (the unsigned Breviarium.ipa)
# into a fixed local folder using the GitHub CLI, and prints where it landed.
#
# Requires: the GitHub CLI (gh), authenticated (gh auth login), run from inside a clone
# of the Breviarium repository so gh can infer the repo from the git remote.
#
# Usage: .\scripts\get-ipa.ps1

$ErrorActionPreference = "Stop"

$destDir = Join-Path $env:USERPROFILE "Downloads\BreviariumIPA"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) not found on PATH. Install it with: winget install --id GitHub.cli"
    exit 1
}

if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

# This gh CLI version has no --clobber/overwrite flag on "run download", and errors if
# the destination file already exists -- so clear any previous download first.
$existingIpa = Join-Path $destDir "Breviarium.ipa"
if (Test-Path $existingIpa) {
    Remove-Item $existingIpa -Force
}

Write-Host "Looking up the latest successful build-ipa.yml run..."
$runId = gh run list --workflow "build-ipa.yml" --status success --limit 1 --json databaseId --jq ".[0].databaseId"

if ([string]::IsNullOrWhiteSpace($runId)) {
    Write-Error "No successful build-ipa.yml run found. Trigger one first: gh workflow run build-ipa.yml"
    exit 1
}

Write-Host "Downloading artifact from run $runId into $destDir ..."
gh run download $runId --name "Breviarium-ipa" --dir $destDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "gh run download failed."
    exit $LASTEXITCODE
}

$ipaPath = Join-Path $destDir "Breviarium.ipa"
if (Test-Path $ipaPath) {
    Write-Host ""
    Write-Host "IPA ready at: $ipaPath"
} else {
    Write-Warning "Download finished but Breviarium.ipa was not found in $destDir. Contents:"
    Get-ChildItem $destDir | ForEach-Object { Write-Host " - $($_.Name)" }
    exit 1
}
