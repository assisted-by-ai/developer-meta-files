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

fail=0

if GITHUB_TOKEN='ghp_goodToken_123' ghorg_token >/dev/null 2>&1; then
  :
else
  printf '%s\n' 'FAIL: rejected safe token format from env' >&2
  fail=1
fi

if GITHUB_TOKEN='ghp_bad"token' ghorg_token >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: accepted token containing quote (curl --config injection risk)' >&2
  fail=1
fi

if GITHUB_TOKEN='ghp_bad token' ghorg_token >/dev/null 2>&1; then
  printf '%s\n' 'FAIL: accepted token containing space' >&2
  fail=1
fi

exit "${fail}"
