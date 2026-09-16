#!/usr/bin/env perl
# Generates the job manifest for scripts/generate-oracle-fixtures.sh: one tab-separated
# line per render (date, priest, lang2, output path relative to data/oracle-fixtures/raw),
# per docs/PLAN.md's reduced oracle-fixture scope --
#
#   - main sweep: every date 2025-01-01..2040-12-31, Latin only, priest off;
#   - spot check: ~100-130 dates, weighted toward CLAUDE.md's named edge cases, each
#     rendered with the *other* three option combinations (priest on/Latin, priest
#     off/English, priest on/English) -- the main sweep already covers priest off/Latin
#     for every date, spot-checked ones included.
#
# Easter is the standard anonymous Gregorian algorithm (Meeus/Jones/Butcher), used only to
# pick which real calendar dates go into the spot check -- not part of the engine itself
# (BreviariumKit's own Computus.swift is the actual, separately-tested implementation).
use strict;
use warnings;

my $START_YEAR = 2025;
my $END_YEAR   = 2040;

# CLAUDE.md names these years directly: the Annunciation transferred in 2027/2029/2035,
# St Joseph transferred in 2035, the latest Easter in the range (2038), an early one
# (2035), and 16 September 2026's title block is the visual spec's own worked example.
my %priority_year = map { $_ => 1 } (2026, 2027, 2029, 2035, 2038);

sub is_leap {
  my $y = shift;
  return ($y % 4 == 0 && $y % 100 != 0) || ($y % 400 == 0);
}

my @days_in_month = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

sub month_day_to_ordinal {
  my ($month, $day, $year) = @_;
  my $n = $day;
  for (my $m = 1; $m < $month; $m++) {
    $n += $days_in_month[$m - 1];
    $n++ if $m == 2 && is_leap($year);
  }
  return $n;
}

sub ordinal_to_month_day {
  my ($n, $year) = @_;
  my @dim = @days_in_month;
  $dim[1]++ if is_leap($year);
  my $month = 1;
  while ($n > $dim[$month - 1]) {
    $n -= $dim[$month - 1];
    $month++;
  }
  return ($month, $n);
}

# Returns Easter Sunday's ordinal day-of-year for $year.
sub easter_ordinal {
  my $year = shift;
  my $a = $year % 19;
  my $b = int($year / 100);
  my $c = $year % 100;
  my $d = int($b / 4);
  my $e = $b % 4;
  my $f = int(($b + 8) / 25);
  my $g = int(($b - $f + 1) / 3);
  my $h = (19 * $a + $b - $d - $g + 15) % 30;
  my $i = int($c / 4);
  my $k = $c % 4;
  my $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7;
  my $m = int(($a + 11 * $h + 22 * $l) / 451);
  my $month = int(($h + $l - 7 * $m + 114) / 31);
  my $day   = (($h + $l - 7 * $m + 114) % 31) + 1;
  return month_day_to_ordinal($month, $day, $year);
}

# One manifest line for a date given as an ordinal day-of-year (may fall in the
# previous/next year for Easter-relative offsets near a year boundary -- handled by
# carrying the ordinal past [1, length-of-year] into the adjacent year).
sub emit_date {
  my ($lines, $year, $ordinal, $priest, $lang2, $label) = @_;
  my $len = is_leap($year) ? 366 : 365;
  while ($ordinal < 1) {
    $year--;
    $ordinal += is_leap($year) ? 366 : 365;
  }
  while ($ordinal > $len) {
    $ordinal -= $len;
    $year++;
    $len = is_leap($year) ? 366 : 365;
  }
  my ($month, $day) = ordinal_to_month_day($ordinal, $year);
  my $date_param = "$month-$day-$year";
  my $suffix = $lang2 eq 'Latin-Bea' ? 'latin' : 'bilingual';
  my $priest_tag = $priest ? 'priestY' : 'priestN';
  my $outfile = sprintf("spot-check/%04d-%02d-%02d_%s_%s_%s.txt", $year, $month, $day, $priest_tag, $suffix, $label);
  push @$lines, join("\t", $date_param, $priest, $lang2, $outfile);
}

sub emit_spot_check_combos {
  my ($lines, $year, $ordinal, $label) = @_;
  emit_date($lines, $year, $ordinal, 1, 'Latin-Bea', $label);
  emit_date($lines, $year, $ordinal, 0, 'English', $label);
  emit_date($lines, $year, $ordinal, 1, 'English', $label);
}

my @lines;

# --- Main sweep: every date, priest off, Latin only ---
for (my $year = $START_YEAR; $year <= $END_YEAR; $year++) {
  my $len = is_leap($year) ? 366 : 365;
  for (my $ordinal = 1; $ordinal <= $len; $ordinal++) {
    my ($month, $day) = ordinal_to_month_day($ordinal, $year);
    my $date_param = "$month-$day-$year";
    my $outfile = sprintf("main/%04d/%04d-%02d-%02d_priestN_latin.txt", $year, $year, $month, $day);
    push @lines, join("\t", $date_param, 0, 'Latin-Bea', $outfile);
  }
}

# --- Spot check: priority years get the full named-edge-case list ---
for my $year ($START_YEAR .. $END_YEAR) {
  my $easter = easter_ordinal($year);

  # Christ the King: last Sunday of October, fixed under the 1960 rubrics (not
  # Easter-relative, and not moved to the end of the liturgical year as in the later
  # Novus Ordo calendar). Day-of-week via the epoch-day trick (1 Jan 2000 was a
  # Saturday), so this doesn't depend on any weekday helper elsewhere in the repo.
  my $oct31 = month_day_to_ordinal(10, 31, $year);
  my $days_since_2000 = 0;
  for (my $y = 2000; $y < $year; $y++) { $days_since_2000 += is_leap($y) ? 366 : 365; }
  $days_since_2000 += $oct31 - 1;
  my $weekday = (6 + $days_since_2000) % 7;    # 0 = Sunday, matching 1 Jan 2000 = Saturday.
  my $christ_king_ordinal = $oct31 - $weekday;

  if ($priority_year{$year}) {
    my %edge_cases = (
      'new-year'          => month_day_to_ordinal(1, 1, $year),
      'epiphany'          => month_day_to_ordinal(1, 6, $year),
      'septuagesima'      => $easter - 63,
      'ash-wednesday'     => $easter - 46,
      'passion-sunday'    => $easter - 14,
      'palm-sunday'       => $easter - 7,
      'holy-thursday'     => $easter - 3,
      'good-friday'       => $easter - 2,
      'holy-saturday'     => $easter - 1,
      'easter'            => $easter,
      'easter-octave-sat' => $easter + 6,
      'ascension'         => $easter + 39,
      'pentecost'         => $easter + 49,
      'trinity-sunday'    => $easter + 56,
      'corpus-christi'    => $easter + 60,
      'sacred-heart'      => $easter + 68,
      'all-saints'        => month_day_to_ordinal(11, 1, $year),
      'all-souls'         => month_day_to_ordinal(11, 2, $year),
      'christmas-eve'     => month_day_to_ordinal(12, 24, $year),
      'christmas'         => month_day_to_ordinal(12, 25, $year),
      'christ-the-king'   => $christ_king_ordinal,
    );
    # 16 September 2026: the visual spec's own worked example (CLAUDE.md).
    $edge_cases{'visual-spec-example'} = month_day_to_ordinal(9, 16, $year) if $year == 2026;

    for my $label (sort keys %edge_cases) {
      emit_spot_check_combos(\@lines, $year, $edge_cases{$label}, $label);
    }
  } else {
    # A single evenly-spaced fill date for general feria/feast/Sunday coverage, plus
    # Christ the King, in every other year.
    emit_spot_check_combos(\@lines, $year, 200, 'fill');
    emit_spot_check_combos(\@lines, $year, $christ_king_ordinal, 'christ-the-king');
  }
}

print "$_\n" for @lines;
