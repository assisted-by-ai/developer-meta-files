## Bash Style Guide (AI-Assisted)

This guide collects the bash style choices applied to scripts under
the assisted-by-ai org. Brief by design; the goal is "readable by both
human reviewers and AI tools without a 50-page rulebook."

## ASCII only

Source code and commit messages are ASCII only. No unicode characters,
no smart quotes, no em dashes, no zero-width spaces, no checkmarks,
no arrows, no emoji. AI tools tend to render bullet lists and prose
with cosmetic unicode (e.g. U+2014 em dash, U+2192 right-arrow); strip
those down to ASCII (`-`, `->`).

`grep -rPI '[^\x00-\x7F]' .` finds offenders in tracked files.

## File header: AI-Assisted marker

Every script (or substantial doc) created from scratch by an AI tool
gets the literal token `AI-Assisted` in the file header, on its own
comment line directly under the copyright block:

```
#!/bin/bash

## Copyright (C) 2026 - 2026 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
## See the file COPYING for copying conditions.

## AI-Assisted

## <brief description of what the script does>
```

This is the only attribution the project accepts. No author lines,
no co-author lines, no individual credits in source files. This is to
discourage contribution spam to receive attribution.

The marker exists so reviewers can `grep -r -- AI-Assisted` to find files
that warrant extra scrutiny, not as a credit line.

Pre-existing files that an AI tool only edits do not get the marker
unless the edit is substantial (rewrite, migration, restructure).

## Strict shell options

Every new script starts with:

```
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace
shopt -s inherit_errexit
shopt -s shift_verbose
```

* `inherit_errexit` makes `errexit` apply inside `$( ... )` substitutions
(off by default in bash 5.x).
* `shift_verbose` makes `shift` log when called past argv end.

## Function definitions

A function definition's closing `}` is followed by ONE blank line
before the next top-level statement, function definition, or
top-level comment. Without the blank line the next block runs into
the function body visually and the function boundary is harder to
spot in a 600-line file.

```
foo() {
   local x

   x="$1"
   printf '%s\n' "${x}"
}

bar() {
   ...
}
```

Exception: end of file. A trailing function may end with `}` on the
final line; no terminating blank required there.

## Variables

* All variable expansions use `${var}`, never bare `$var`.
* Do not initialize a variable to `${var:-}` unless `set -o nounset`
  forces it. `${var:-}` is a real signal that the variable may not be
  defined; using it where it is defined hides actual init-order bugs.
* `local var1 var2 var3` declares all locals on a single line at the
  top of the function. Then assign on subsequent lines:

```
foo() {
   local owner repo patch

   owner="$1"
   repo="$2"

   ## ... logic
}
```

* Never use `local x="$(cmd)"`. `local` always exits 0, so `cmd`'s
  failure is masked. Declare with `local x` then assign on the next
  line.
* Globals at the top of the script, grouped, with one comment block
  per knob and a blank line between assignments.
* Variable names in messages should be wrapped in single quotes so
  trailing/leading whitespace shows: `printf '%s\n' "error: '${path}'
  not found" >&2`.
* Do not use very short var names such as `${e}`. Variable names should
  be descriptive.

## printf

Always `printf '%s\n' "..."`. The format string is fixed; everything
else goes in the data string. No `%d`, no `%q` (except where you
genuinely need shell-escaping), no extra `\n` in the format.

* Multi-line block: ONE quoted string with embedded newlines, so only
  one open/close quote pair.
* Multiple distinct lines: one `printf '%s\n' "..."` per line.
* Blank line: `printf '%s\n' ""` (not `\n` in the format).
* Double quotes preferred for the string. `printf '%s\n' "string"`
* Single quotes for string are also acceptable if more readable in
  specific cases such as: `printf '%s\n' '"has" "a" "lot" "quotes"'`
  to avoid escaping `\"`.

### printf vs log: use `log` for ad-hoc messages

`printf '%s\n' "..."` is for the script's *structured output* - lines
that downstream tools (tests, log scrapers, the operator's eye) match
against a known prefix. `DRY-RUN: ...`, `ok:   ...`, `warn: ...`,
`error: ...`, `forked: ...`, `=== summary ===` - those stay as
`printf` so the prefix is exact.

For an *informational* message that is not part of a contract -
"no source repos matched.", "no new forks needed.", "skipping X
because Y" - use `log notice "..."` (or `log info`, `log warn`,
`log error` as appropriate). The log helpers prefix the script name
and a level tag (`script.sh [NOTICE]: ...`) which is the right
context for an ad-hoc message and the wrong context for a structured
prefix line.

```
## structured output - test greps for ^ok: and ^warn:
printf '%s\n' "ok:   ${label} [${status}]"
printf '%s\n' "warn: '${label}' ['${status}']" >&2

## ad-hoc info - reader wants the script name + level tag
log notice 'no new forks needed.'
log warn   "skipping '${repo}': default branch missing"
```

## Flags

* Long option names whenever the tool supports one: `--quiet`,
  `--ignore-case`, `--lines=1`, `--unique`. `wc --lines`,
  `sort --unique`, etc.
* Combined short flags get split: `rm -rf` -> `rm -r -f`,
  `declare -gA` -> `declare -g -A`.
* End-of-options separator `--` everywhere the tool supports one and
  positional args follow flags. Verified working before adding:
  `git`, `grep`, `sed`, `tr`, `jq`, `head`, `tail`, `stat`,
  `mktemp`, `wc`, `sort`, `cat`, `rm`, `safe-rm`, `mkdir`, `find`.
  Do verify end-of-options separator being supported before use.

## Case statements

* `;;` on its own line, never trailing the last statement.
* Each statement on its own line; multi-statement single-line arms
  are split.
* Reserved-name patterns and metachar-looking literals are quoted:
  `'.git'` not `.git`, `'-'*` not `-*`.

```
case "${kind}" in
   repo)
      max_len="${MAX_REPO}"
      ;;
   user)
      max_len="${MAX_USER}"
      ;;
esac
```

## Sourcing helper-scripts

```
# shellcheck source=/usr/libexec/helper-scripts/<file>
source "${HELPER_SCRIPTS_PATH:-}"/usr/libexec/helper-scripts/<file>
```

Empty `${HELPER_SCRIPTS_PATH}` -> system install at
`/usr/libexec/helper-scripts/`. A caller running with helper-scripts
as a submodule sets the variable to the submodule path.

The `# shellcheck source=` directive uses the *real install path* so
shellcheck can follow it during the lint pass (which runs after
helper-scripts is installed). Don't fall back to `source=/dev/null` --
that silences cross-file checks. shellcheck doesn't expand the
`${HELPER_SCRIPTS_PATH:-}` prefix at lint time, but the explicit
`source=` directive points it at the absolute path that exists in the
CI environment.

Each consumer sources every helper-scripts file it uses directly.
Do not rely on transitive sourcing (one helper-scripts file pulling
in another). For example, `log_run_die.sh` happens to source
`strings.bsh` for its own use; if your script also calls
`is_whole_number` from `strings.bsh`, source `strings.bsh` itself
even if `log_run_die.sh` is already sourced. Otherwise a future
refactor that drops the transitive source breaks you silently.

`wc` invocations should be preceded by sourcing `wc-test.sh` so a
broken `wc` binary fails loudly rather than silently producing an
empty count.

Reuse strings.bsh's `is_whole_number`, `validate_safe_filename`,
`check_is_alpha_numeric` etc. before reimplementing.

## Command availability checks

Use `has` from `helper-scripts/has.sh`, not `command -v X >/dev/null
2>&1`. `has` is a thin wrapper that also verifies the result is
executable and guards against aliases/functions:

```
# shellcheck source=/usr/libexec/helper-scripts/has.sh
source "${HELPER_SCRIPTS_PATH:-}"/usr/libexec/helper-scripts/has.sh

has github-org-fork \
   || die 1 'github-org-fork not found on PATH (install incomplete).'
```

The exception is `ci/install-helper-scripts.sh` itself -- helper-
scripts isn't installed yet at that point, so it falls back to plain
`command -v`.

### Pre-flight at the top, not scattered

A tool's runtime command dependencies are checked *once*, near the
top of the script's setup phase, not lazily inside the function that
happens to need each one. Lazy checks fail halfway through a per-repo
loop and leave partial state behind; a top-of-file pre-flight bails
before any mutation runs.

Where a family of tools shares the same deps (e.g. all `github-org-*`
tools need `curl`, `jq`, `sanitize-string`, and `git`), the lib that
they all source provides a single helper they call:

```
ghorg_require_deps git    ## base set + 'git' for tools that exec git
```

Do not add an inline `has git || die ...` at the per-feature site
when the shared pre-flight already covers it.

## Workflow scripts: standalone, not inline

Substantial bash logic does not belong inside a workflow YAML's
`run: |` block. If the step is more than ~5 lines (or has any
control flow, retry loop, polling, error handler), put it in a
standalone script under `ci/` and have the workflow call it:

```yaml
- name: Start systemd-enabled Debian container
  run: bash ci/dry-run-start-container.sh dryrun "${DEBIAN_IMAGE}"
```

Reasons:

* `shellcheck` only sees real `.sh` files, not YAML blocks. Inline
  shell silently bypasses linting.
* A standalone script can be reproduced from a developer machine.
  Inline-in-YAML is reproducible only by re-running the workflow.
* Code review reads cleaner - diff is line-level, not embedded
  inside YAML indentation games.
* The script's args become the workflow's contract with the
  script: explicit, named, testable.

### Naming: workflow YAML and its scripts share a prefix

A workflow YAML and the ci scripts it invokes use the same base
name (or share a prefix). A reader scanning either folder can find
the matching counterpart at a glance:

```
.github/workflows/dry-run.yml
                  ^  (same prefix)
                  v
ci/dry-run-derivative-maker.sh
ci/dry-run-install.sh
ci/dry-run-start-container.sh
ci/dry-run-install-container-git.sh
```

Allowed exceptions:

* Workflows that only call a third-party action and have no project
  ci script (e.g. `codeql.yml`, `scorecard.yml`).
* Generic shared installers that are reused by multiple workflows
  (e.g. `ci/install-helper-scripts.sh`, `ci/install-genmkfile.sh`)
  -- the "install-X" prefix indicates the shared helper, not a
  workflow.

If a script grows enough to need its own workflow file (e.g. a
"live-probe" that's logically separate from the mock test suite it
currently piggy-backs on), give it its own YAML with a matching
name rather than tucking it into an unrelated workflow.

## Errors and logging

Use `log` and `die` from `helper-scripts/log_run_die.sh`:

```
log error "couldn't read '${path}'"   ## log only
log warn  "..."
log notice  "..."
log info  "..."
die 1 "fatal: ..."                     ## logs error then exit 1
[ "$#" -ge 2 ] || die 64 "missing value for --include"
```

`die <code> <msg>` is the one-liner for "log error then exit." Use
it for top-level fatal sites (parser guards, missing prerequisites,
unrecoverable state). Inside a function that should return rather
than exit, use `log error "..."; return N` instead.

Don't write `printf '%s\n' 'error: ...' >&2; exit N`; that's the
ad-hoc form `die` replaces.

## File deletion

Use `safe-rm` instead of `rm`. Long flag form: `safe-rm --force --`
or `safe-rm --recursive --force --`. `safe-rm` consults a blocklist
before deleting.

## Traps

Trap targets are standalone named functions, never inline command
strings. The function references variables from the calling scope
via bash dynamic scoping; the trap is registered AFTER those
variables are initialized so the reference is `nounset`-safe with
no `${var:-}` default.

```
foo_cleanup_tmp() {
   safe-rm --force -- "${tmp_file}"
}

foo() {
   local tmp_file

   tmp_file="$(mktemp)"
   trap foo_cleanup_tmp RETURN

   ## ... use ${tmp_file}
}
```

## Null command

`true` instead of `:` for no-op placeholders. Pass a descriptive
message so xtrace logs convey intent:

```
true "INFO: ghorg_api: HTTP 429 - will retry"
```

Bare `true > "${file}"` is fine for "truncate file". `while true` is
fine for an infinite loop.

## printf inline command substitution

Pre-compute substitutions into a named variable instead of inlining:

```
## avoid:
printf '%s\n' "warn: $(my_helper "${value}")"

## prefer:
result="$(my_helper "${value}")"
printf '%s\n' "warn: ${result}"
```

Reads better, surfaces intermediate names, and stops printf format
strings from growing into expressions.

## API-derived strings (untrusted bytes)

Treat every byte returned by an external service as untrusted:

* Identifier sinks (URL paths, file paths, command-line arguments):
  pass through a strict allowlist validator (e.g. `^[A-Za-z0-9._-]+$`)
  or a numeric-only regex with length cap before use.
* Display sinks (printf to stdout/stderr): pass through a sanitizer
  (e.g. `sanitize-string`) that strips ANSI escapes, control chars,
  HTML markup, and truncates oversized payloads.
* Don't sanitize the raw API body before parsing - the parser (jq)
  is the schema validator. Sanitize after extraction, before display.
