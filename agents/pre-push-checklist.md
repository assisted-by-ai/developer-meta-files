# Pre-push checklist (AI-Assisted)

Skim before every push. Scope: any change to scripts under
`usr/bin/`, `usr/libexec/developer-meta-files/`, `ci/`, or
`agents/`. Project-specific rules in
[github-org-tools.md](github-org-tools.md); general bash style in
[bash-style-guide.md](bash-style-guide.md).

The list is grouped by phase. Skip items that don't apply to your
diff; don't skip a phase. Each item cites the relevant rule (R-NNN
for bash style, G-NNN for github-org-* / dm-* project rules) so
you can grep for the underlying contract.


## Static checks

    [ ] bash -n on every changed *.sh / *.bsh / usr/bin/dm-* /
        usr/bin/github-org-*
    [ ] shellcheck --external-sources (-x) on the same set
        (catches SC2317 unreachable-via-source for callbacks
        invoked indirectly across files)
    [ ] LC_ALL=C grep -PlI '[^\x00-\x7F]' on changed files
        (R-001 ASCII only)
    [ ] LC_ALL=C grep -P '[^\x00-\x7F]' on the commit message
        (R-001 ASCII only)


## Style spot-check (touched code only)

    [ ] ${var} braces, no bare $var (R-020)
    [ ] local var1 var2 var3 at top of function, blank line,
        then assigns (R-021)
    [ ] no 'local x="$(cmd)"' (R-022; masks failure)
    [ ] arr=() initialized before any access under nounset (R-025)
    [ ] long flags where supported (R-060)
    [ ] '--' end-of-options on tools that accept it (R-062;
        verified against the actual binary before adding)
    [ ] case ;; on its own line; reserved patterns quoted (R-070,
        R-072)
    [ ] case-pattern interpolations quoted: "${x}" not ${x}
        (R-073; SC2254)
    [ ] # shellcheck source=<real path>, never /dev/null (R-080,
        R-081)
    [ ] log/die from log_run_die.sh, not ad-hoc 'printf %s\n
        "error: ..." >&2' (R-040, R-110)
    [ ] has from has.sh, not 'command -v X >/dev/null 2>&1'
        (R-090)
    [ ] safe-rm, not rm (R-120)
    [ ] traps as named functions, registered after vars init
        (R-051)
    [ ] true "INFO: ..." not bare ':' (R-130)
    [ ] no $(cmd) inside printf format strings; hoist to a named
        variable (R-033)
    [ ] blank line after function closing brace (R-050)
    [ ] errexit not toggled around capture; use 'rc=0; out=$(cmd)
        || rc=$?' (R-011)


## Project-rule spot-check (github-org-* / dm-* surface)

    [ ] API-derived string into URL/file/git/curl arg ->
        ghorg_validate_name (G-001) or numeric regex + length
        cap (G-002)
    [ ] API-derived string into printf/log -> ghorg_safe_print
        (G-003)
    [ ] No new <( ... ) process substitution feeding a read loop
        without a documented reason (audit checklist in G-doc)
    [ ] No new '&' background worker mutating shared state
        without a tempfile (R-052, G-033)
    [ ] New non-2xx success status (e.g., DELETE 404) passed as
        the 5th arg to policy_api_call (G-034)


## Mock-API test spot-check

    [ ] Tests capture combined output via 2>&1 (G-041; bare
        $(cmd) is empty after the printf->log conversion)
    [ ] No '^prefix' anchored greps that target the log-line
        prefix; use --fixed-strings substrings or exit-code
        checks (G-042)
    [ ] Prefer exit-code-based assertions to output-format-based
        ones (G-043)
    [ ] Reinstall ALL changed binaries before running the suite
        locally - 'sudo cp' the full set or 'genmkfile install'.
        A partial install masks regressions because the tool
        still in /usr/bin is the unrefactored one.
    [ ] Run the FULL ci/test-github-org-tools.sh suite, not just
        the file matching the changed surface. Cross-file
        contracts break otherwise.


## External invocations (this is what bit me on rounds 2 and 3)

    [ ] Any new external command / new flag -> run it locally
        first with the actual argv being constructed
        (e.g., 'git check-ref-format refs/heads/main' BEFORE
        pushing; --branch / -- variants of git check-ref-format
        return rc=129 even on valid input)
    [ ] If the command is sensitive to flags vs. positional,
        test both legitimate and adversarial inputs
        ('-foo', '..', empty)
    [ ] If a docstring claims a parameter accepts a particular
        form (e.g., '404|409' alternation), parametrically
        verify the bash construct supports it. Bash case-pattern
        expansion does NOT interpret '|' as alternation across
        an interpolated value (R-073).


## Refactor-aware re-check

    [ ] After ANY refactor that changes function scope, signature,
        or boundary: re-trace data flow end-to-end. (Footgun:
        dropped 'positional=()' init when collapsing a parser
        block; the test only failed under nounset + missing-arg
        path, not the happy path.)
    [ ] After ANY printf->log conversion: re-check tests that
        anchor on '^' prefix or rely on stdout-only capture.
    [ ] After dropping a flag's parallelism / backgrounding:
        verify the new sequential code-path actually reaches
        every item (not just compiles).


## Commit

    [ ] Every new file from scratch has 'AI-Assisted' marker
        (R-002)
    [ ] Commit message states the WHY in 1-3 sentences before
        the diff narration
    [ ] No emoji, no smart quotes, no em dashes in commit message
        (R-001)
    [ ] Cite relevant R-NNN / G-NNN rules in commit body when the
        change applies or relaxes one
