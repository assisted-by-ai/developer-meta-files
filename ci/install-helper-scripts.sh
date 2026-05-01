#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## CI helper: install Kicksecure/helper-scripts from its upstream git
## repository using the genmkfile install flow. helper-scripts then
## provides sanitize-string (and its supporting Python packages),
## which github-org-lib.bsh's safe-print path requires.
##
## Depends on genmkfile already being installed on PATH (see
## ci/install-genmkfile.sh).
##
## Runs in a clean container; no idempotence required.

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

if ! command -v genmkfile >/dev/null 2>&1; then
   printf '%s\n' \
      'error: genmkfile not on PATH; run ci/install-genmkfile.sh first.' >&2
   exit 1
fi
if ! command -v safe-rm >/dev/null 2>&1; then
   printf '%s\n' \
      'error: safe-rm not on PATH; required for secure cleanup of temporary clone directory.' >&2
   exit 1
fi

readonly upstream_url='https://github.com/Kicksecure/helper-scripts.git'
readonly helper_scripts_ref="${HELPER_SCRIPTS_REF:-}"
clone_dir=''

if [ -z "${helper_scripts_ref}" ]; then
   printf '%s\n' \
      'error: HELPER_SCRIPTS_REF is empty.' \
      '       Set it to an immutable 40-hex git commit SHA to avoid mutable-branch supply-chain risk.' >&2
   exit 1
fi
if ! [[ "${helper_scripts_ref}" =~ ^[0-9a-f]{40}$ ]]; then
   printf '%s\n' \
      "error: HELPER_SCRIPTS_REF must be a 40-hex commit SHA, got '${helper_scripts_ref}'." >&2
   exit 1
fi

clone_dir="$(mktemp -d)"
cleanup_clone_dir() {
   [ -n "${clone_dir}" ] || return 0
   safe-rm --recursive --force -- "${clone_dir}"
}
trap cleanup_clone_dir EXIT

git clone --depth=1 --no-tags -- "${upstream_url}" "${clone_dir}"
cd -- "${clone_dir}"
git checkout --detach -- "${helper_scripts_ref}"
GENMKFILE_DEBUG=1 genmkfile install
