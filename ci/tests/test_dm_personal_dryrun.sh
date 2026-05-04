#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Mock-API test: dm-github-personal-policy --dry-run produces
## DRY-RUN: lines for each planned per-repo API call without
## emitting a real ok:/warn: from a successful PUT/PATCH/DELETE.
## Companion to test_dm_dryrun.sh (which covers dm-github-policy /
## the org tool); together they pin the dry-run output of the two
## tools that share github-policy-lib.bsh.
##
## Fixtures used:
##   GET_users_personal-test-user             - account-type lookup
##   GET_users_personal-test-user_repos       - one public non-archived
##                                              non-fork repo
##                                              (backup-mirror), one
##                                              archived, one fork
##                                              (both filtered out)

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

out="$(dm-github-personal-policy personal-test-user --dry-run 2>&1)"

fail=0
required=(
   'DRY-RUN: personal-test-user/backup-mirror: fork-PR approval=all_external_contributors'
   'DRY-RUN: personal-test-user/backup-mirror: workflow GITHUB_TOKEN read-only'
   'DRY-RUN: personal-test-user/backup-mirror: actions enabled=true, allowed=selected'
   'DRY-RUN: personal-test-user/backup-mirror: selected-actions allow-list'
   'DRY-RUN: personal-test-user/backup-mirror: settings (wiki/projects/discussions off, secret-scan on)'
   'DRY-RUN: personal-test-user/backup-mirror: delete Pages site (if any)'
   'DRY-RUN: personal-test-user/backup-mirror: upsert ruleset dm-github-personal-policy default-branch protection'
   'DRY-RUN: personal-test-user/backup-mirror: upsert ruleset dm-github-personal-policy tag protection'
)
for needle in "${required[@]}"; do
   if ! grep --quiet --fixed-strings -- "${needle}" <<< "${out}"; then
      printf '%s\n' "FAIL: missing expected fragment: ${needle}" >&2
      fail=1
   fi
done

## --dry-run must not emit a real "ok:" or "warn:" prefix that comes
## from policy_api_call's success/failure path - those mean a real
## PUT/PATCH/DELETE ran.
if grep --quiet --extended-regexp -- '^ok:|^warn:' <<< "${out}"; then
   printf '%s\n' \
      'FAIL: --dry-run unexpectedly printed ok:/warn: real-API output:' >&2
   grep --extended-regexp -- '^ok:|^warn:' <<< "${out}" | head -5 >&2
   fail=1
fi

## Filter check: archived + fork repos must NOT be planned. The
## fixture has 'old-archived' (archived) and 'upstream-fork' (fork)
## alongside the one public non-archived non-fork repo.
unexpected=( old-archived upstream-fork )
for repo in "${unexpected[@]}"; do
   if grep --quiet --fixed-strings -- "personal-test-user/${repo}" <<< "${out}"; then
      printf '%s\n' "FAIL: ${repo} should be filtered out of dry-run" >&2
      fail=1
   fi
done

exit "${fail}"
