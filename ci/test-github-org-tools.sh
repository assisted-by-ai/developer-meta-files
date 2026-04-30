#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Runs every executable test_*.sh in ci/tests/. Each test is
## hermetic: GHORG_MOCK=1 + GHORG_MOCK_DIR=ci/fixtures route every
## API call to a local fixture file. No network, no real tokens.
##
## A test passes if it exits 0; fails on any non-zero exit. Output is
## captured per-test and only printed on failure to keep success runs
## quiet.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose
shopt -s nullglob

## Refuse to run outside CI. The suite is allowed to mutate the local
## /tmp directory and assumes a clean container-style environment;
## running it on a developer workstation would leave debris behind
## and might accidentally install symlinks into /usr/. CI=true is set
## by GitHub Actions and by the workflow at .github/workflows/.
if [ "${CI:-}" != "true" ]; then
   printf 'error: this script must run with CI=true (GitHub Actions or equivalent).\n' >&2
   printf '       Set CI=true to acknowledge before invoking.\n' >&2
   exit 1
fi

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
TESTS_DIR="$SCRIPT_DIR/tests"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"

if [ ! -d "$TESTS_DIR" ]; then
  printf 'error: tests directory missing: %s\n' "$TESTS_DIR" >&2
  exit 1
fi

## Sanity check: the lib path the tests source must exist (i.e. the
## package must be installed or the script tree present at the
## expected location).
if [ ! -r /usr/libexec/developer-meta-files/github-org-lib.bsh ]; then
  printf 'error: /usr/libexec/developer-meta-files/github-org-lib.bsh not found.\n' >&2
  printf '       Install developer-meta-files or symlink the source-tree files.\n' >&2
  exit 1
fi

## sanitize-string is a runtime dep of github-org-lib for safe
## display. The tests use the lib's audit/error paths which call it.
if ! command -v sanitize-string >/dev/null 2>&1; then
  printf 'error: sanitize-string not on PATH (helper-scripts).\n' >&2
  exit 1
fi

pass=0
fail=0
fail_names=()

for test_path in "$TESTS_DIR"/test_*.sh; do
  test_name="$(basename -- "$test_path")"
  printf '== %s ==\n' "$test_name"
  log_file="$(mktemp)"
  if GHORG_MOCK_DIR="$FIXTURE_DIR" bash -- "$test_path" > "$log_file" 2>&1; then
    printf '  PASS\n'
    pass=$(( pass + 1 ))
  else
    printf '  FAIL\n'
    sed 's/^/    | /' -- "$log_file"
    fail=$(( fail + 1 ))
    fail_names+=( "$test_name" )
  fi
  rm -f -- "$log_file"
done

printf '\n=== summary: %s passed, %s failed ===\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  printf 'failures:\n'
  printf '  - %s\n' "${fail_names[@]}"
  exit 1
fi
