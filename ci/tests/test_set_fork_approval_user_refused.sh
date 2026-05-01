#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Mock-API test: github-org-set-fork-approval refuses to operate on
## a User account (the underlying endpoint is org-only).

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

set +e
out="$(github-org-set-fork-approval --get assisted-by-ai 2>&1)"
rc=$?
set -e

if [ "${rc}" -eq 0 ]; then
  printf '%s\n' "FAIL: expected non-zero exit, got 0. Output:" "${out}" >&2
  exit 1
fi
if ! grep --quiet --ignore-case -- "is a 'User', not an Organization" <<< "${out}"; then
  printf '%s\n' \
    'FAIL: expected "User, not an Organization" refusal. Output:' \
    "${out}" >&2
  exit 1
fi

exit 0
