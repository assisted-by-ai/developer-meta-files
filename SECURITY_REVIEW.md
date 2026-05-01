# Security Review (May 1, 2026)

Scope:
- ci/probe-live-unauth.sh
- ci/test-github-org-tools.sh
- ci/tests/* listed by requester
- ci/install-helper-scripts.sh
- .github/workflows/test-github-org-tools.yml
- .github/workflows/policy-live.yml
- usr/libexec/developer-meta-files/github-org-lib.bsh
- usr/bin/dm-github-policy
- usr/bin/dm-fork-sync
- usr/bin/github-org-push
- usr/bin/github-org-clone
- usr/bin/github-org-fork

## Findings

### 1) High: Unpinned third-party dependency in CI install path (supply-chain risk)
`ci/install-helper-scripts.sh` clones `Kicksecure/helper-scripts` from the mutable `master` branch and executes installer logic. This allows upstream branch compromise/force-push to alter CI behavior without any change in this repository. The two workflows invoke this script directly.

- Affected files:
  - `ci/install-helper-scripts.sh`
  - `.github/workflows/test-github-org-tools.yml`
  - `.github/workflows/policy-live.yml`

**Recommendation:** Pin helper-scripts to an immutable commit SHA (or a signed, immutable release artifact + checksum verification), and make SHA updates explicit via PR.

### 2) Medium: PATH trust for security-critical helper binaries
The tools trust first-hit PATH entries for `sanitize-string` and `safe-rm`. In hostile execution environments, PATH hijacking could replace these helpers and weaken output sanitization or temp-file deletion behavior.

- Affected files:
  - `usr/libexec/developer-meta-files/github-org-lib.bsh` (`ghorg_require_deps`, `ghorg_safe_print`, cleanup path)

**Recommendation:** Prefer absolute paths for helper binaries after discovery (e.g., resolve with `command -v` once, store/read-only variables, optionally verify ownership/permissions in CI images).

## Positive controls observed
- Strong input validation (`ghorg_validate_name`) before URL-path and file-path sinks.
- Response-output sanitization via `sanitize-string` before terminal display.
- Token handling avoids argv leaks (`curl --config -`) and suppresses xtrace during secret usage.
- HTTPS-only transport constraints for curl, redirect cap, pagination cap, retry/backoff bounds.
- Clone hardening blocks `file://` and `ext::` protocols and disables LFS smudge during clone.

