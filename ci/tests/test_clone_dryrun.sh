#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Mock-API test: github-org-clone --dry-run lists exactly the
## non-archived non-fork non-private repos from the source org.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose

if [ "${CI:-}" != "true" ]; then
   printf 'error: this script must run with CI=true (GitHub Actions or equivalent).\n' >&2
   exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
FIXTURE_DIR="$(cd -- "$SCRIPT_DIR/../fixtures" && pwd)"

export GHORG_MOCK=1
export GHORG_MOCK_DIR="$FIXTURE_DIR"

out="$(github-org-clone --dry-run org-ai-assisted /tmp/clone-dryrun-out)"

## Expected: exactly two repos selected (derivative-maker,
## helper-scripts). The other three (archived/fork/private) must be
## filtered out by the default flags.
expected_repos=( derivative-maker helper-scripts )
unexpected=( old-archived some-fork private-thing )

fail=0
for repo in "${expected_repos[@]}"; do
  if ! grep --quiet -- "DRY-RUN: clone .*${repo}\.git" <<< "$out"; then
    printf 'FAIL: expected %s in dry-run output\n' "$repo" >&2
    fail=1
  fi
done
for repo in "${unexpected[@]}"; do
  if grep --quiet -- "DRY-RUN: clone .*${repo}\.git" <<< "$out"; then
    printf 'FAIL: %s should be filtered out\n' "$repo" >&2
    fail=1
  fi
done

if ! grep --quiet -- '^2 repos to process' <<< "$out"; then
  printf 'FAIL: expected "2 repos to process" header\n' >&2
  fail=1
fi

exit "$fail"
