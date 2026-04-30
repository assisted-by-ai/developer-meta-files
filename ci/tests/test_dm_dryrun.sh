#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Mock-API test: dm-github-policy --dry-run produces DRY-RUN: prefixed
## lines for each planned API call without making any writes. Covers
## the org-level apply path; the per-repo loop uses ghorg_list_repos
## (read GET) and per-repo PATCHes also flagged DRY-RUN:.

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
FIXTURE_DIR="$(cd -- "$SCRIPT_DIR/../fixtures" && pwd)"

export GHORG_MOCK=1
export GHORG_MOCK_DIR="$FIXTURE_DIR"

out="$(dm-github-policy --dry-run 2>&1)"

fail=0
required=(
   'DRY-RUN: org-ai-assisted: fork-PR approval=all_external_contributors'
   'DRY-RUN: org-ai-assisted: workflow GITHUB_TOKEN read-only, no PR approval'
   'DRY-RUN: org-ai-assisted: actions enabled=all, allowed=selected'
   'DRY-RUN: org-ai-assisted: selected-actions = github-owned + verified-creators'
   'DRY-RUN: org-ai-assisted: members policy (default-perm=read, no member create)'
   'DRY-RUN: org-ai-assisted: upsert code-security configuration dm-github-policy code security'
   'DRY-RUN: org-ai-assisted: attach code-security configuration scope=all'
   'DRY-RUN: org-ai-assisted: set code-security configuration default_for_new_repos=all'
   'skip: org-ai-assisted: 2FA enforcement must be set via UI'
   'skip: org-ai-assisted: PAT policy toggles must be set via UI'
   'skip: org-ai-assisted: GitHub App / OAuth App policies must be set via UI'
   'DRY-RUN: org-ai-assisted: upsert ruleset dm-github-policy default-branch protection'
   'DRY-RUN: org-ai-assisted: upsert ruleset dm-github-policy tag protection'
   '=== summary ==='
)
for needle in "${required[@]}"; do
   if ! grep --quiet --fixed-strings -- "$needle" <<< "$out"; then
      printf '%s\n' "FAIL: missing expected fragment: $needle" >&2
      fail=1
   fi
done

## --dry-run must not emit a real "ok:" or "warn:" prefix that comes
## from api_call's success/failure path - those mean a real PATCH ran.
if grep --quiet --extended-regexp -- '^ok:|^warn:' <<< "$out"; then
   printf '%s\n' \
      'FAIL: --dry-run unexpectedly printed ok:/warn: real-API output:' >&2
   grep --extended-regexp -- '^ok:|^warn:' <<< "$out" | head -5 >&2
   fail=1
fi

exit "$fail"
