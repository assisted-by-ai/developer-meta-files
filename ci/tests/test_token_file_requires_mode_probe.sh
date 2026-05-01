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

tmpd="$(mktemp -d)"
trap 'safe-rm --recursive --force -- "${tmpd}"' EXIT

token_file="${tmpd}/github-token"
printf '%s\n' 'ghp_TestToken_123' > "${token_file}"
chmod 600 "${token_file}"

# Force permission-probe failure path.
stat() { return 1; }

set +e
out="$(GHORG_TOKEN_FILE="${token_file}" ghorg_token 2>&1 >/dev/null)"
rc=$?
set -e

if [ "${rc}" -eq 0 ]; then
  printf '%s\n' 'FAIL: ghorg_token succeeded despite failed mode probe' >&2
  exit 1
fi
if ! printf '%s' "${out}" | grep -q 'unable to determine permissions'; then
  printf '%s\n' 'FAIL: expected mode-probe refusal message not found' >&2
  exit 1
fi
