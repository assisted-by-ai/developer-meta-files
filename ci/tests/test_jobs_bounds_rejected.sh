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

check_reject() {
  set +e
  out="$("$@" 2>&1)"
  rc=$?
  set -e
  if [ "${rc}" -ne 64 ]; then
    printf '%s\n' "FAIL: expected exit 64, got ${rc}: $*" >&2
    fail=1
    return
  fi
  if ! printf '%s' "${out}" | grep -q 'invalid --jobs value'; then
    printf '%s\n' "FAIL: missing invalid --jobs diagnostic: $*" >&2
    fail=1
  fi
}

check_reject github-org-clone --jobs 0 org-ai-assisted
check_reject github-org-push --jobs 9999 . org-ai-assisted

exit "${fail}"
