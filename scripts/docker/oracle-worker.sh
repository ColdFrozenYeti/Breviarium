#!/usr/bin/env bash
# Runs *inside* the divinum-officium container (see docker-compose.yml's volume mount).
# Takes one tab-separated job line: date<TAB>priest<TAB>lang2<TAB>outfile-relative-to-/oracle-raw
#
# Renders one Vespers page via officium.pl invoked directly as a Perl CLI script (data/
# SOURCE.md explains why: this is what DO's own regress/scripts/generate-diff.sh does,
# and is much faster than the HTTP path for a multi-thousand-call sweep), then strips
# HTML down to plain text and collapses whitespace. J-to-I orthography is deliberately
# *not* applied here -- it's applied once, at OracleTests compare time, using
# BreviariumKit's own LatinOrthography, so fixture generation has no Swift dependency at
# all and stays runnable purely from this container.
set -euo pipefail

IFS=$'\t' read -r date_param priest lang2 outfile <<< "$1"

out_path="/oracle-raw/${outfile}"
mkdir -p "$(dirname "$out_path")"

# lang1 is always Latin-Bea (CLAUDE.md fixes the Pius XII/Bea psalter permanently). For
# "Latin only" jobs lang2 must be passed as Latin-Bea too, not plain Latin -- officium.pl's
# own psalmvar-based Latin->Latin-Bea auto-upgrade only ever mutates *one* of lang1/lang2
# (each check reads the other's *already-updated* value), so relying on it here leaves
# lang1 and lang2 unequal and defeats the single-column collapse this depends on.
args=(version="Rubrics 1960" command=prayVespera "date=${date_param}" lang1=Latin-Bea "lang2=${lang2}" content=1)
if [ "$priest" = "1" ]; then
  args+=(priest=1)
fi

perl /var/www/web/cgi-bin/horas/officium.pl "${args[@]}" 2>/dev/null \
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
