#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## Unit-style test of ghorg_compute_backoff_seconds and the
## rate-limit-wait header parser. Network-free; loads the lib and
## calls the helpers directly with crafted inputs.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose

if [ "${CI:-}" != "true" ]; then
   printf 'error: this script must run with CI=true (GitHub Actions or equivalent).\n' >&2
   exit 1
fi

# shellcheck disable=SC1091
source /usr/libexec/developer-meta-files/github-org-lib.bsh

fail=0
expect() {
  local desc="$1" want="$2" got="$3"
  if [ "$got" != "$want" ]; then
    printf 'FAIL: %s: want %q got %q\n' "$desc" "$want" "$got" >&2
    fail=1
  fi
}

## Backoff doubles per attempt up to GHORG_MAX_BACKOFF_SECONDS.
expect 'backoff[0]' '30'   "$(ghorg_compute_backoff_seconds 0)"
expect 'backoff[1]' '60'   "$(ghorg_compute_backoff_seconds 1)"
expect 'backoff[2]' '120'  "$(ghorg_compute_backoff_seconds 2)"
expect 'backoff[3]' '240'  "$(ghorg_compute_backoff_seconds 3)"

## Retry-After header takes precedence.
hdr="$(mktemp)"
trap 'rm -f -- "$hdr"' EXIT
printf 'HTTP/2 429\r\nRetry-After: 17\r\nX-RateLimit-Reset: 99999999999\r\n\r\n' > "$hdr"
expect 'parse Retry-After' '17' "$(ghorg_parse_rate_limit_wait "$hdr")"

## X-RateLimit-Reset used as fallback. Check just that we get a
## non-empty positive integer for a reset 10 seconds in the future.
future=$(( $(date -u +%s) + 10 ))
printf 'HTTP/2 403\r\nX-RateLimit-Remaining: 0\r\nX-RateLimit-Reset: %s\r\n\r\n' "$future" > "$hdr"
got="$(ghorg_parse_rate_limit_wait "$hdr")"
if [ -z "$got" ] || ! [[ "$got" =~ ^[0-9]+$ ]]; then
  printf 'FAIL: parse X-RateLimit-Reset: got %q\n' "$got" >&2
  fail=1
fi

## Reset already in the past -> empty (caller falls back to backoff).
past=$(( $(date -u +%s) - 100 ))
printf 'HTTP/2 403\r\nX-RateLimit-Reset: %s\r\n\r\n' "$past" > "$hdr"
expect 'parse stale reset' '' "$(ghorg_parse_rate_limit_wait "$hdr")"

## No relevant header -> empty.
printf 'HTTP/2 200\r\nServer: github.com\r\n\r\n' > "$hdr"
expect 'parse no rate-limit hdr' '' "$(ghorg_parse_rate_limit_wait "$hdr")"

exit "$fail"
