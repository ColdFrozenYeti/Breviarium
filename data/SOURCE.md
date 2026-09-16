# Divinum Officium — pinned source

- **Repository:** https://github.com/DivinumOfficium/divinum-officium
- **Vendored as:** git submodule at `data/divinum-officium`
- **Pinned commit:** `126a07f91ede04664108abb6fb20ace3f4de14b9`
- **Pinned on:** 2026-09-16, tracking `master` as of commit date 2026-09-14
- **Licence:** MIT (see `data/divinum-officium/LICENSE`). The notice must be shown on the
  app's About screen, per `CLAUDE.md`.

No preference was stated for which commit to pin (see `docs/PLAN.md`, Decisions §3), so
this pins to `master` at the time M0 was done. Bumping the pin later means: update the
submodule, re-run `scripts/generate-oracle-fixtures.*`, and re-record the new hash and
date here.

## Running it locally

`scripts/docker/docker-compose.yml` builds the container from this pinned checkout (not
the floating `ghcr.io/divinumofficium/divinum-officium:master` image mentioned in DO's own
README, which would drift out from under the pin):

```
docker compose -f scripts/docker/docker-compose.yml up --build -d
curl http://localhost:8080/cgi-bin/horas/officium.pl
docker compose -f scripts/docker/docker-compose.yml down
```

## Invocation, for M1/M4

DO's own regression tooling (`regress/scripts/generate-diff.sh`) does **not** go over
HTTP — it invokes the CGI script directly as a Perl program, with parameters passed as
`key=value` command-line arguments, e.g.:

```
perl web/cgi-bin/horas/officium.pl version="Rubrics 1960" command=prayVespera date=1-1-2025
```

`office_script_path`/`hour_command`/`long_version` in that same script show the exact
mapping from short version names (`1960` → `Rubrics 1960`) and hour names (`Vespera` →
`prayVespera`) DO itself uses. This is very likely faster than the HTTP path for the
oracle-fixture sweep in M4 (no Starman/Plack request overhead per call) and should be
confirmed and used in `scripts/generate-oracle-fixtures.*`. It should be run inside the
container (`docker compose exec` or `docker run`) so the Perl module environment from the
Dockerfile (Plack, CGI::Compile, etc.) is present. Full parameter mapping — including how
the Pius XII Psalter and Priest options are passed — is M1's job
(`docs/do-format.md`), not resolved here.
