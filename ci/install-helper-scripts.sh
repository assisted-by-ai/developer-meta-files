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

readonly clone_dir='/tmp/helper-scripts-install'
readonly UPSTREAM_OWNER='Kicksecure'
readonly upstream_url="https://github.com/${UPSTREAM_OWNER}/helper-scripts.git"

git clone --depth=1 --no-tags --branch=master -- "${upstream_url}" "${clone_dir}"
cd -- "${clone_dir}"
GENMKFILE_DEBUG=1 genmkfile install
