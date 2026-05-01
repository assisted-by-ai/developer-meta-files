#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose

if [ "${CI:-}" != "true" ]; then
   printf '%s\n' 'error: this script must run with CI=true (GitHub Actions or equivalent).' >&2
   exit 1
fi

if ! command -v sanitize-string >/dev/null 2>&1; then
   printf '%s\n' 'error: sanitize-string not found on PATH.' >&2
   exit 1
fi

# shellcheck disable=SC1091
source /usr/libexec/developer-meta-files/github-org-lib.bsh

set +e
out="$(GITHUB_TOKEN='bad token with space' ghorg_api GET '/rate_limit' 2>&1)"
rc=$?
set -e

if [ "${rc}" -eq 0 ]; then
  printf '%s\n' 'FAIL: ghorg_api unexpectedly succeeded with invalid configured token' >&2
  exit 1
fi
if ! printf '%s' "${out}" | grep -qi 'refusing anonymous fallback'; then
  printf '%s\n' 'FAIL: expected invalid-token refusal diagnostic not found' >&2
  exit 1
fi
