#!/usr/bin/env bash
# Generates one of Beta 1's oracle fixture sets (docs/Beta_1_plan.md, "Oracle fixtures"):
# every date of the given years, rendered by the pinned Divinum Officium checkout on the
# host (Perl with CGI.pm, e.g. Debian/Ubuntu's libcgi-pm-perl), one archive per year.
#
#   vulgate    Vulgate Latin only, priest off, "flat" pages -> vulgate/<year>.tar.gz
#   bilingual  Vulgate Latin + English, priest off, "rows"  -> bilingual/<year>.tar.gz
#   holdout    Vulgate Latin + English, priest off and on, "rows"
#                                                          -> holdout/<year>-bilingual.tar.gz
#
# "flat" and "rows" are scripts/docker/oracle-worker.sh's output formats. Host renders
# were checked byte-identical to the container's (docs/PLAN.md, B1-M2), and the alpha's
# Bea sets are made by generate-oracle-fixtures.sh and generate-holdout-fixtures.sh.
#
# Usage: scripts/generate-fixture-set.sh vulgate 2025 2040
#        scripts/generate-fixture-set.sh holdout 2044 2044
set -euo pipefail

set_name="${1:?usage: $0 vulgate|bilingual|holdout <first-year> <last-year>}"
first="${2:?first year}"
last="${3:?last year}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

case "$set_name" in
  vulgate)   lang2=Latin;   format=flat; suffix=latin.txt;     priests="0"; dest=vulgate ;;
  bilingual) lang2=English; format=rows; suffix=bilingual.tsv; priests="0"; dest=bilingual ;;
  holdout)   lang2=English; format=rows; suffix=bilingual.tsv; priests="0 1"; dest=holdout ;;
  *) echo "unknown set: $set_name" >&2; exit 2 ;;
esac

raw_dir="data/oracle-fixtures/raw-$set_name"
rm -rf "$raw_dir"
mkdir -p "$raw_dir" "data/oracle-fixtures/$dest"

perl -e '
  my ($first, $last, $lang2, $format, $suffix, @priests) = @ARGV;
  for my $y ($first .. $last) {
    my $leap = ($y % 4 == 0 && $y % 100 != 0) || $y % 400 == 0;
    my @dim = (31, $leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    for my $m (1 .. 12) {
      for my $d (1 .. $dim[$m - 1]) {
        my $iso = sprintf("%04d-%02d-%02d", $y, $m, $d);
        for my $p (@priests) {
          my $tag = $p ? "priestY" : "priestN";
          print "$m-$d-$y\t$p\t$lang2\t$y/${iso}_${tag}_$suffix\tLatin\t$format\n";
        }
      }
    }
  }
' "$first" "$last" "$lang2" "$format" "$suffix" $priests > "$raw_dir/manifest.tsv"
echo "==> $(wc -l < "$raw_dir/manifest.tsv") renders ($set_name, $first-$last)"

DO_ROOT="$repo_root/data/divinum-officium" ORACLE_RAW="$raw_dir" \
  xargs -d '\n' -P "$(nproc)" -I{} bash scripts/docker/oracle-worker.sh "{}" < "$raw_dir/manifest.tsv"

empty_count=$(find "$raw_dir" -mindepth 2 -type f -empty | wc -l | tr -d ' ')
if [ "$empty_count" -gt 0 ]; then
  echo "ERROR: $empty_count empty renders" >&2
  exit 1
fi

for year in $(seq "$first" "$last"); do
  name="$year"
  [ "$set_name" = holdout ] && name="$year-bilingual"
  # Sorted names and a fixed mtime keep the archives byte-identical across runs.
  tar -C "$raw_dir" --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -cf - "$year" \
    | gzip -n > "data/oracle-fixtures/$dest/$name.tar.gz"
  echo "    $dest/$name.tar.gz ($(du -h "data/oracle-fixtures/$dest/$name.tar.gz" | cut -f1))"
done
rm -rf "$raw_dir"
