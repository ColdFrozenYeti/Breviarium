#!/usr/bin/env bash
# Generates a hold-out oracle year: every date of one year, Latin/Bea only, rendered
# twice (priest off and priest on), packed as data/oracle-fixtures/holdout/<year>.tar.gz.
# A hold-out year lies outside the 2025-2040 main sweep the engine was tuned against, so
# its tests (Tests/OracleTests/Holdout*OracleTests.swift) are an out-of-sample check.
#
# Uses the same scripts/docker/oracle-worker.sh as generate-oracle-fixtures.sh. By default
# it runs on the host against the pinned checkout (needs only Perl with CGI.pm, e.g.
# Debian/Ubuntu's libcgi-pm-perl). Host renders were verified byte-identical to the container-generated
# fixtures (all of 2026 priest off, and every priest-on spot-check file) -- docs/PLAN.md.
#
# Usage: scripts/generate-holdout-fixtures.sh 2044
set -euo pipefail

year="${1:?usage: $0 <year>}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

raw_dir="data/oracle-fixtures/raw-holdout"
rm -rf "$raw_dir"
mkdir -p "$raw_dir" data/oracle-fixtures/holdout

perl -e '
  my $y = shift;
  my $leap = ($y % 4 == 0 && $y % 100 != 0) || $y % 400 == 0;
  my @dim = (31, $leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  for my $m (1 .. 12) {
    for my $d (1 .. $dim[$m - 1]) {
      my $iso = sprintf("%04d-%02d-%02d", $y, $m, $d);
      print "$m-$d-$y\t0\tLatin-Bea\t$y/${iso}_priestN_latin.txt\n";
      print "$m-$d-$y\t1\tLatin-Bea\t$y/${iso}_priestY_latin.txt\n";
    }
  }
' "$year" > "$raw_dir/manifest.tsv"
echo "==> $(wc -l < "$raw_dir/manifest.tsv") renders for $year"

DO_ROOT="$repo_root/data/divinum-officium" ORACLE_RAW="$raw_dir" \
  xargs -d '\n' -P "$(nproc)" -I{} bash scripts/docker/oracle-worker.sh "{}" < "$raw_dir/manifest.tsv"

empty_count=$(find "$raw_dir/$year" -type f -empty | wc -l | tr -d ' ')
if [ "$empty_count" -gt 0 ]; then
  echo "ERROR: $empty_count empty renders" >&2
  exit 1
fi

tar -C "$raw_dir" -czf "data/oracle-fixtures/holdout/${year}.tar.gz" "$year"
echo "==> data/oracle-fixtures/holdout/${year}.tar.gz ($(du -h "data/oracle-fixtures/holdout/${year}.tar.gz" | cut -f1))"
rm -rf "$raw_dir"
