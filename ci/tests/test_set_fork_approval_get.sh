#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Mock-API test: github-org-set-fork-approval --get reads and prints
## the current policy.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose

if [ "${CI:-}" != "true" ]; then
   printf '%s\n' \
      'error: this script must run with CI=true (GitHub Actions or equivalent).' >&2
   exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
FIXTURE_DIR="$(cd -- "${SCRIPT_DIR}/../fixtures" && pwd)"

export GHORG_MOCK=1
export GHORG_MOCK_DIR="${FIXTURE_DIR}"

out="$(github-org-set-fork-approval --get org-ai-assisted)"

## Fixture sets approval_policy=first_time_contributors.
if ! grep --quiet -- 'current approval_policy: first_time_contributors' <<< "${out}"; then
  printf '%s\n' \
    'FAIL: expected "current approval_policy: first_time_contributors"' \
    "${out}" >&2
  exit 1
fi
if ! grep --quiet -- '^org: org-ai-assisted$' <<< "${out}"; then
  printf '%s\n' 'FAIL: expected "org: org-ai-assisted" header' >&2
  exit 1
fi

exit 0
