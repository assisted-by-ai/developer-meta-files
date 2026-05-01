#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## CI helper: install Kicksecure/genmkfile from its upstream git
## repository into the system. genmkfile then becomes available on
## PATH so subsequent CI steps can use `genmkfile install` to install
## helper-scripts and developer-meta-files itself.
##
## Runs in a clean container; no idempotence required. Refuses to run
## outside CI to avoid clobbering a developer workstation.

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

readonly clone_dir='/tmp/genmkfile-install'
readonly upstream_url='https://github.com/Kicksecure/genmkfile.git'

git clone --depth=1 --branch=master -- "${upstream_url}" "${clone_dir}"
cd -- "${clone_dir}"
GENMKFILE_DEBUG=1 ./usr/bin/genmkfile deb-all-dep
GENMKFILE_DEBUG=1 ./usr/bin/genmkfile install
