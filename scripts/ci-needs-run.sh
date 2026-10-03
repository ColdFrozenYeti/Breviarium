#!/usr/bin/env bash
# Build tooling only. Decides whether a pull request's push needs this workflow's heavy
# jobs: GitHub's own `paths:` filter looks at the whole pull request's diff against its
# base, so once a pull request touches the Kit, every later push (docs included) reran
# everything (asked about on 26 September 2026, B5-M0).
#
# Usage: ci-needs-run.sh <workflow file> <extended regex of paths that matter>
# Writes `run=true|false` to $GITHUB_OUTPUT. It compares the head with the last commit
# on this branch whose run of the same workflow succeeded -- not with the previous push,
# whose run may have been cancelled -- and runs whenever it can't tell.
set -euo pipefail
workflow="$1"
pattern="$2"
out="${GITHUB_OUTPUT:-/dev/stdout}"

if [ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]; then
  echo "run=true" >> "$out"; exit 0
fi

head="$PR_HEAD_SHA"
last=$(gh run list --repo "$GITHUB_REPOSITORY" --workflow "$workflow" --branch "$PR_HEAD_REF" \
  --event pull_request --status success --limit 20 --json headSha --jq '.[].headSha' 2>/dev/null \
  | while read -r sha; do
      if git merge-base --is-ancestor "$sha" "$head" 2>/dev/null; then echo "$sha"; break; fi
    done || true)

if [ -z "$last" ]; then
  echo "No earlier passing run of $workflow on this branch: running."
  echo "run=true" >> "$out"; exit 0
fi
if [ "$last" = "$head" ]; then
  echo "This commit already passed $workflow: running anyway (a re-run was asked for)."
  echo "run=true" >> "$out"; exit 0
fi

changed=$(git diff --name-only "$last" "$head")
echo "Changed since $last, the last commit that passed $workflow:"
echo "$changed"
if echo "$changed" | grep -qE "$pattern"; then
  echo "run=true" >> "$out"
else
  echo "Nothing $workflow checks has changed: its jobs are skipped."
  echo "run=false" >> "$out"
fi
