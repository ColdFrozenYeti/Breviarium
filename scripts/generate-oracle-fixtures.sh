#!/usr/bin/env bash
# Generates the oracle fixtures used by Tests/OracleTests (docs/PLAN.md's testing
# strategy): renders every Vespers page in the reduced sweep via the pinned Divinum
# Officium checkout running in Docker, strips HTML down to plain text, and packs the
# result into compressed archives under data/oracle-fixtures/.
#
# Requires Docker Desktop running (see docs/windows-swift-setup.md). Takes a while --
# ~6,200 renders -- so this is meant to be run as a one-off local batch job, not from CI
# (matching CLAUDE.md: "Build and CI tooling may use whatever is convenient", and
# data/SOURCE.md: re-run only when the DO pin moves or the covered set changes).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

raw_dir="data/oracle-fixtures/raw"
manifest="$raw_dir/manifest.tsv"

echo "==> Generating job manifest"
mkdir -p "$raw_dir"
perl scripts/oracle-date-list.pl > "$manifest"
job_count=$(wc -l < "$manifest")
echo "    $job_count jobs"

echo "==> Starting the divinum-officium container"
docker compose -f scripts/docker/docker-compose.yml up --build -d

echo "==> Running the sweep inside the container (this takes a while)"
docker compose -f scripts/docker/docker-compose.yml exec -T divinum-officium bash -c '
  set -euo pipefail
  xargs -d "\n" -P "$(nproc)" -I{} /usr/local/bin/oracle-worker.sh "{}" < /oracle-raw/manifest.tsv
  echo "    rendered $(find /oracle-raw/main /oracle-raw/spot-check -type f 2>/dev/null | wc -l) files"
'

echo "==> Checking for empty (failed) renders"
empty_count=$(find "$raw_dir/main" "$raw_dir/spot-check" -type f -empty 2>/dev/null | wc -l | tr -d ' ')
if [ "$empty_count" -gt 0 ]; then
  echo "    WARNING: $empty_count empty output files -- inspect before trusting the fixtures:"
  find "$raw_dir/main" "$raw_dir/spot-check" -type f -empty 2>/dev/null | head -20
else
  echo "    none"
fi

echo "==> Packing into compressed archives"
mkdir -p data/oracle-fixtures/main
for year_dir in "$raw_dir"/main/*/; do
  year="$(basename "$year_dir")"
  tar -C "$raw_dir/main" -czf "data/oracle-fixtures/main/${year}.tar.gz" "$year"
  echo "    main/${year}.tar.gz ($(du -h "data/oracle-fixtures/main/${year}.tar.gz" | cut -f1))"
done
if [ -d "$raw_dir/spot-check" ]; then
  tar -C "$raw_dir" -czf "data/oracle-fixtures/spot-check.tar.gz" "spot-check"
  echo "    spot-check.tar.gz ($(du -h data/oracle-fixtures/spot-check.tar.gz | cut -f1))"
fi

echo "==> Done. Raw (uncompressed) output is in $raw_dir -- safe to delete once the"
echo "    archives above look right; it is not meant to be committed."
