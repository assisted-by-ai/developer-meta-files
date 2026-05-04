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
##                                              archived (filtered out),
##                                              and one fork
##                                              (upstream-fork) which
##                                              IS in scope - forks own
##                                              their own .github/
##                                              workflows + ruleset
##                                              settings, so they get
##                                              the same lockdown.

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
   'DRY-RUN: personal-test-user/backup-mirror: actions enabled=false (CI runs disabled)'
   'DRY-RUN: personal-test-user/backup-mirror: settings (wiki/projects/discussions off, secret-scan on)'
   'DRY-RUN: personal-test-user/backup-mirror: delete Pages site (if any)'
   'DRY-RUN: personal-test-user/backup-mirror: upsert ruleset dm-github-personal-policy default-branch protection'
   'DRY-RUN: personal-test-user/backup-mirror: upsert ruleset dm-github-personal-policy tag protection'
   ## Fork repo: same lockdown applies. Picking one of the per-repo
   ## settings to confirm the fork is reached at all - if it isn't,
   ## the include_forks=1 wiring regressed.
   'DRY-RUN: personal-test-user/upstream-fork: actions enabled=false (CI runs disabled)'
   'DRY-RUN: personal-test-user/upstream-fork: upsert ruleset dm-github-personal-policy default-branch protection'
)
for needle in "${required[@]}"; do
   if ! grep --quiet --fixed-strings -- "${needle}" <<< "${out}"; then
      printf '%s\n' "FAIL: missing expected fragment: ${needle}" >&2
      fail=1
   fi
done

## --dry-run must not emit a real success/failure line. Those come
## from policy_api_call's 2xx / non-2xx branch and route through
## 'log notice "ok: ..."' / 'log warn "..."', which produce
## "<script> [NOTICE]: ok: ..." and "<script> [WARN]: ..." lines.
## Either substring/level-tag inside the line means a real
## PUT/PATCH/DELETE ran.
if grep --quiet --extended-regexp -- ' ok: |\[WARN\]:' <<< "${out}"; then
   printf '%s\n' \
      'FAIL: --dry-run unexpectedly printed real-API ok:/warn output:' >&2
   grep --extended-regexp -- ' ok: |\[WARN\]:' <<< "${out}" | head -5 >&2
   fail=1
fi

## Filter check: actions enabled=true and the selected-actions
## allow-list must NOT appear (we disabled Actions entirely instead).
forbidden=(
   'actions enabled=true'
   'selected-actions allow-list'
)
for needle in "${forbidden[@]}"; do
   if grep --quiet --fixed-strings -- "${needle}" <<< "${out}"; then
      printf '%s\n' "FAIL: unexpected legacy fragment present: ${needle}" >&2
      fail=1
   fi
done

## Filter check: archived repos are still excluded by the API
## listing. Forks ARE in scope now (see required[] above).
if grep --quiet --fixed-strings -- 'personal-test-user/old-archived' <<< "${out}"; then
   printf '%s\n' 'FAIL: archived repo should be filtered out of dry-run' >&2
   fail=1
fi

exit "${fail}"
