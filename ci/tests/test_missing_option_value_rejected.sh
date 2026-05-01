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

fail=0

check_missing_arg() {
  local expected rc out
  expected='missing value for'

  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e

  if [ "${rc}" -ne 64 ]; then
    printf '%s\n' "FAIL: expected exit 64, got ${rc}: $*" >&2
    fail=1
    return
  fi
  if ! printf '%s' "${out}" | grep -q "${expected}"; then
    printf '%s\n' "FAIL: missing expected diagnostic for: $*" >&2
    fail=1
  fi
}

check_missing_arg github-org-clone --include
check_missing_arg github-org-fork --actions
check_missing_arg github-org-push --jobs

exit "${fail}"
