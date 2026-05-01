# github-org-* / dm-github-policy / dm-fork-sync security (AI-Assisted)

What this surface specifically defends against and what it
deliberately trusts. General threat-modeling principles in
[`agents/security.md`](security.md).

## Threat boundary: GitHub REST API responses

Every byte returned by `api.github.com` (or whatever `${GHORG_API}`
points at) is treated as untrusted. Two enforcement points:

1. **Identifier sinks** - URL paths, file paths, git arguments,
   command-line args. Every API-extracted name passes through
   `ghorg_validate_name` (strict ASCII allowlist `^[A-Za-z0-9._-]+$`,
   length cap, reserved-name and `..` rejection). Numeric IDs pass a
   `^[0-9]+$` regex with `GHORG_MAX_ID_LEN=20` byte cap before being
   interpolated into URL paths.

2. **Display sinks** - everything that flows to a `printf` for an
   operator-visible message goes through `ghorg_safe_print` (which
   calls `sanitize-string` from helper-scripts). That strips ANSI
   escapes, control characters, HTML markup, and truncates oversized
   payloads. A hostile API response cannot smuggle terminal escapes
   or runaway output onto the operator's screen.

Resource caps in the lib bound the local damage a hostile or
misbehaving server can cause through pagination
(`GHORG_MAX_PAGES=100`), redirect chains (`GHORG_MAX_REDIRS=5`),
oversized bodies (curl `--max-filesize 10MB`), or oversized
"numeric" ids.

Clone-time hardening in `github-org-clone`:
- `GIT_LFS_SKIP_SMUDGE=1` blocks the LFS smudge filter from
  auto-fetching attacker-chosen objects when an upstream's
  `.gitattributes` points binaries at LFS.
- `--config protocol.file.allow=never` and
  `--config protocol.ext.allow=never` block the file:// and ext::
  helper protocols, which have been used in past CVEs to read local
  files or run shell commands when a hostile upstream redirects a
  sub-fetch.

## Audit checklist (when changing the lib or tools)

- Any new place an API-derived string flows into a URL path, file
  path, or git/curl arg? It needs `ghorg_validate_name` (or numeric
  regex + length cap) before that sink.
- Any new place an API-derived string flows into a `printf` for the
  operator? It needs `ghorg_safe_print` first.
- Any new `<( ... )` process substitution feeding a `read` loop?
  Errors inside the substitution are invisible to errexit; consider
  pre-capturing into a string with `$( ... )` instead, or document
  why the substitution form is intentional.
- Any new background `&` worker that needs to update shared state?
  Bash variable updates from a backgrounded subshell are lost on
  join; use a tempfile + atomic appends (PIPE_BUF=4096 on Linux)
  the way the api_counter_file pattern does.
