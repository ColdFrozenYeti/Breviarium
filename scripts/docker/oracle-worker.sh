#!/usr/bin/env bash
# Runs *inside* the divinum-officium container (see docker-compose.yml's volume mount).
# Takes one tab-separated job line:
#   date<TAB>priest<TAB>lang2<TAB>outfile-relative-to-/oracle-raw[<TAB>lang1[<TAB>format]]
# lang1 defaults to Latin-Bea (the alpha's psalter) so existing manifests keep working;
# Latin is the Vulgate (docs/psalters-and-english.md section 1). format is "flat" (the
# default: the whole page as one whitespace-collapsed line) or "rows" (one line per table
# row, its cells separated by a tab, each cell normalised on its own). Bilingual fixtures
# use "rows" so the Latin and English columns stay apart: J-to-I applies to the Latin
# cell only, and pairing can be checked row by row.
#
# Renders one Vespers page via officium.pl invoked directly as a Perl CLI script (data/
# SOURCE.md explains why: this is what DO's own regress/scripts/generate-diff.sh does,
# and is much faster than the HTTP path for a multi-thousand-call sweep), then strips
# HTML down to plain text and collapses whitespace. J-to-I orthography is deliberately
# *not* applied here -- it's applied once, at OracleTests compare time, using
# BreviariumKit's own LatinOrthography, so fixture generation has no Swift dependency at
# all and stays runnable purely from this container.
set -euo pipefail

IFS=$'\t' read -r date_param priest lang2 outfile lang1 format <<< "$1"
lang1="${lang1:-Latin-Bea}"
format="${format:-flat}"

# Both paths default to the container layout (docker-compose.yml). Override them to run
# against a host checkout instead: DO_ROOT=<repo>/data/divinum-officium ORACLE_RAW=<dir>.
# The host needs only Perl with CGI.pm for this CLI path (no Plack/Starman).
do_root="${DO_ROOT:-/var/www}"
oracle_raw="${ORACLE_RAW:-/oracle-raw}"

out_path="${oracle_raw}/${outfile}"
mkdir -p "$(dirname "$out_path")"

# For a Bea "Latin only" job lang2 must be passed as Latin-Bea too, not plain Latin -- officium.pl's
# own psalmvar-based Latin->Latin-Bea auto-upgrade only ever mutates *one* of lang1/lang2
# (each check reads the other's *already-updated* value), so relying on it here leaves
# lang1 and lang2 unequal and defeats the single-column collapse this depends on.
args=(version="Rubrics 1960" command=prayVespera "date=${date_param}" "lang1=${lang1}" "lang2=${lang2}" content=1)
if [ "$priest" = "1" ]; then
  args+=(priest=1)
fi

render() {
  perl "${do_root}/web/cgi-bin/horas/officium.pl" "${args[@]}" 2>/dev/null
}

if [ "$format" = "rows" ]; then
  render | perl -CSD -0777 -ne '
    s/\A.*?\n\r?\n//s;
    sub clean {
      my $t = shift;
      $t =~ s/<[^>]+>//g;
      $t =~ s/&nbsp;/ /g; $t =~ s/&amp;/&/g; $t =~ s/&lt;/</g; $t =~ s/&gt;/>/g; $t =~ s/&quot;/"/g;
      $t =~ s/\s+/ /g; $t =~ s/^\s+|\s+\z//g;
      return $t;
    }
    my @rows = split /<TR>/i;
    my $head = clean(shift @rows);
    print "$head\n" if length $head;
    for my $row (@rows) {
      my @cells = split /<TD[^>]*>/i, $row;
      shift @cells;
      print join("\t", map { clean($_) } @cells), "\n";
    }
  ' > "$out_path"
  exit 0
fi

render \
  | perl -CSD -0777 -pe '
      s/\A.*?\n\r?\n//s;
      s/<[^>]+>//g;
      s/&nbsp;/ /g;
      s/&amp;/&/g;
      s/&lt;/</g;
      s/&gt;/>/g;
      s/&quot;/"/g;
      s/\s+/ /g;
      s/^\s+|\s+\z//g;
    ' \
  > "$out_path"
