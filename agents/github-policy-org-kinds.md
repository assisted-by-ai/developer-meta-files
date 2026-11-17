# Org kinds and the policy each gets (AI-Assisted)

The `dm-github-*` tools apply one baseline policy with a small set of
deliberate per-kind diffs. Kind names are the values `org_kind()`
returns, so this document and the code share one vocabulary. Companion
to [github-org-tools.md](github-org-tools.md).

## The six roles

| Role | Where it lives | Tool |
| --- | --- | --- |
| SOURCE | Kicksecure, Whonix orgs | `dm-github-org-policy kind=source` |
| MIRROR | org-ai-assisted org | `dm-github-org-policy kind=mirror` |
| PROJECT | secure-terminal, output-lies, computer-security-research orgs | `dm-github-org-policy kind=project` |
| STAGE | kicksecure-stage, whonix-stage orgs | `dm-github-org-policy kind=stage` |
| PERSON | `PERSON_USERS` array | `dm-github-personal-policy target_kind=person` |
| BOT | `BOT_USERS` array | `dm-github-personal-policy target_kind=bot` |

- **SOURCE** holds canonical code maintained in place.
- **MIRROR** holds forks of SOURCE.
- **PROJECT** holds self-contained first-party projects with no
  upstream to file against (secure-terminal app, output-lies site).
- **STAGE** hosts one generated `<org>.github.io` repo per org serving
  the noindex staging wiki build (content maintained in the wiki via
  git-mediawiki; no upstream GitHub repo). No CI, bot-pushed.
- **PERSON** / **BOT** are user-owned mirrors (maintainer accounts /
  the `assisted-by-ai` bot and peers).

"Mirror" means specifically "mirrors Kicksecure / Whonix", not "any org
that is not SOURCE".

## The two axes that drive every diff

1. **Is the code maintained elsewhere?** -> governs issues and alerts.
   A fork (MIRROR) routes issues/alerts upstream where the canonical
   repo already reports them. Code maintained in place (SOURCE,
   PROJECT) keeps issues on.
2. **Where does the CI that acts on a report run?** -> governs
   Dependabot. SOURCE and STAGE disable Actions org-wide, so a bump PR
   there can never carry a verdict. MIRROR and PROJECT keep Actions on,
   so a bump PR is verifiable.

The axes are orthogonal and Dependabot follows the second, not the
first. PVR follows neither (off everywhere -- see below).

## Settings per kind

Applied per-repo on the org side: the org-level Code Security
Configurations API is PAID PLAN ONLY (tested on Free 2026-05).

| Setting | SOURCE | MIRROR | PROJECT | STAGE | PERSON | BOT |
| --- | --- | --- | --- | --- | --- | --- |
| Dependabot alerts | off | **on** | off | off | off | off |
| Dependabot security updates | off | **on** | off | off | off | off |
| Dependabot version updates (`.github/dependabot.yml`) | absent | opt-in/repo | opt-in/repo | absent | - | - |
| PVR (private vulnerability reporting) | off | off | off | off | off | off |
| secret_scanning + push protection | on | on | on | on | on | on |
| branch + tag rulesets | on | on | on | on | on | on |
| ruleset `required_signatures` rule | **on** | off | off | off | **on** | off |
| ruleset bypass actor | `[OrgAdmin]` | `[OrgAdmin]` | `[OrgAdmin]` | `[OrgAdmin]` | `[User]` | `[]` |
| CI / GitHub Actions | off (org-wide) | **on** (allow-list) | **on** | off (org-wide) | off | off |
| `has_issues` | on | off | on | off | - | - |
| `has_wiki` / `has_discussions` | off | off | off | off | - | - |
| GitHub Pages | not touched | not touched | not touched | not touched | `DELETE /pages` | `DELETE /pages` |

API endpoints:
- Dependabot alerts: `PUT /repos/{o}/{r}/vulnerability-alerts` on
  MIRROR, `DELETE` elsewhere.
- Dependabot security updates: `PUT /automated-security-fixes` on
  MIRROR, `DELETE` elsewhere.
- Dependabot version updates: no REST setter at any scope;
  `.github/dependabot.yml` presence IS the switch.
- secret_scanning + push protection: in the repo PATCH body.
- rulesets: `POST /repos/{o}/{r}/rulesets`.

Every `--apply` reconciles the disable side too, so leftovers from
older un-gated runs or UI flips are cleaned up.

### Rulesets

Rulesets stay on everywhere; two attributes pivot on role, dispatched
via `POLICY_RULESET_RULES_<ROLE>` and `POLICY_RULESET_BYPASS_<ROLE>` in
`github-policy-data.bsh`.

- **`required_signatures`** ("allow only signed commits"):
  - On for SOURCE and PERSON -- the repo owner bypasses it (see
    below), non-owner collaborators still get the protection.
  - Off for MIRROR, STAGE and BOT -- AI-assisted / bot pushes carry no
    GPG key matching the bot's GitHub-verified identity, so the rule
    would block every legitimate push.
- **Bypass actor**:
  - SOURCE / MIRROR / PROJECT / STAGE: `[OrgAdmin]` (static; org_id=1
    maps to any org admin).
  - PERSON: `[User: target_user_id]` -- user-owned repos have no
    org-admin equivalent; the maintainer's own user_id (resolved via
    `GET /users/{login}` at apply time) is the owner-bypass.
  - BOT: `[]` -- there is no `required_signatures` rule to bypass, and
    a `User` bypass would let the bot force-push and delete its own
    branches, defeating the `deletion` and `non_fast_forward` rules.

### CI / Actions

SOURCE and STAGE disable Actions org-wide
(`enabled_repositories=none`): canonical CI runs on the project's own
infra, and a STAGE org only serves a Pages legacy-branch build.
PERSON/BOT disable it (mirrors run no workflows). MIRROR and PROJECT
keep it on; MIRROR's allow-list is github-owned + verified-creators --
it is where AI-assisted dev + CI + scanner suites run.

### STAGE profile

STAGE = MIRROR's repo body (issues/wiki/projects/discussions off,
secret-scan on) + all Dependabot off (like SOURCE) + MIRROR's ruleset
(deletion + non_fast_forward, no required_signatures) + PVR off +
SOURCE's org-wide Actions-disabled. It differs from MIRROR only on
Dependabot (all off) and Actions (off), both because it runs no CI.

### PVR

Off on every kind, including SOURCE and PROJECT. Security reports reach
us as OpenPGP-encrypted email (the only channel we watch); the
canonical route is the wiki linked from
`org-ai-assisted/.github/SECURITY.md`
(https://www.kicksecure.com/wiki/Reporting_Bugs#Security_Vulnerabilities
and the Vulnerability Disclosure Policy page). An open GitHub
private-report inbox would be a second one nobody reads -- worse than
none, since a researcher reasonably assumes it is monitored.
`apply_repo_policy` unconditionally `DELETE`s PVR on every repo; there
is no enable constant in `github-policy-data.bsh`. Pinned by
`test_dm_apply_project.sh`.

## Registration drift is a finding

On the default-scope path (no `ORGS_OVERRIDE`),
`dm-github-org-policy` reads `GET /user/memberships/orgs` and keeps the
`role=admin` + `state=active` orgs. It then reports:

- an admin org missing from MIRROR/PROJECT/STAGE_ORGS as `UNREGISTERED`
  (it would otherwise sit unhardened with nothing reporting the gap);
- a registered org the bot is not admin of as `STALE`.

Either fails `--audit` and warns on `--apply`/`--dry-run`.
`ORGS_OVERRIDE` skips the check -- a deliberately narrowed scope is not
an account-wide registration statement. SOURCE is member-only and
intentionally excluded from the writable registered set.

## Dependabot

**Decision (2026-07-31): ALERTS and SECURITY updates run on
org-ai-assisted (MIRROR) only** -- centralized so one CVE inbox is not
split across a repo and its mirror. **VERSION updates follow CI**:
allowed wherever Actions can verify a bump PR (MIRROR, PROJECT,
opt-in per repo), absent where Actions is off org-wide (SOURCE, STAGE).

Every Dependabot output only becomes finishable work where CI can build
and test the result. An unverifiable PR stream is worse than none: it
costs review attention and shows a green merge button backed by
nothing. (This replaces the earlier "alerts belong on the canonical
SOURCE repo" reasoning, now overruled.)

### The three switches

| | ALERTS | SECURITY updates | VERSION updates |
| --- | --- | --- | --- |
| On | `PUT /vulnerability-alerts` | `PUT /automated-security-fixes` | `.github/dependabot.yml` exists |
| Off | `DELETE` same endpoint | `DELETE` same endpoint | delete the file (a commit) |
| Scope | per repo, setting | per repo, setting | per repo, content |
| Org-wide setter | none | none | **none at any scope** |
| Needs config file | no | no | yes |
| Policy constant | `POLICY_REPO_DEPENDABOT_ALERTS` / `_ALERTS_OFF` | `POLICY_REPO_DEPENDABOT_FIXES` / `_FIXES_OFF` | `POLICY_DEPENDABOT_VERSION_UPDATES_OFF_*` (a skip line, not an API call) |

Measured 2026-07-31 against `GET
/orgs/{org}/code-security/configurations`: the object carries
`dependabot_alerts` and `dependabot_security_updates` but no
version-updates field, so the file really is the only switch for the
third column.

**Enable/disable ordering:**
- Disable side: `DEPENDABOT_FIXES_OFF` before `DEPENDABOT_ALERTS_OFF`.
  The security-fixes endpoint returns HTTP 422 once alerts are off --
  the idempotent steady state, captured as ok via `_EXTRA_OK_STATUS=422`
  (see G-035 in `github-org-tools.md`).
- Enable side (reversed): alerts first, because
  `PUT /automated-security-fixes` requires them.
- `dm-github-personal-policy` keeps the active-disable step (step 8)
  commented out: the personal mirrors never had these on.

### How `dependabot.yml` reaches a repo: opt-in, not blanket

`usr/bin/dm-packaging-helper-script` deploys it deliberately NOT to
every repo:

- Canonical copy:
  `developer-meta-files/consumer-templates/.github/dependabot.yml`
  (`canonical_dependabot_yml`).
- `pkg_update_consumer_workflows` refreshes a package's copy from it;
  `dependabot_yml_is_manual` skips any file carrying a
  `## propagation: manual` marker (opt-out for a hand-tuned config).
- A repo with nothing to track carries no file; nothing adds one on its
  behalf. The repos that need it pin third-party Action SHAs -- what
  the W-007 `DEPENDABOT-MISSING` check in `test_workflow_yaml.py` flags.

The `groups:` block (with `applies-to: security-updates`) is the
durable, source-controlled form for per-repo custom grouping on the
mirror.

### Shared-tree consequence (unresolved)

MIRROR repos ff-sync from SOURCE, so `.github/dependabot.yml` on the
mirror IS the SOURCE file -- one object in one history. The
version-updates column therefore cannot be split along the org-kind
axis by file presence alone: a mirror-only version bump would need the
config to live somewhere not ff-synced from SOURCE. Recorded as a
maintenance-model question, not decided here. The alerts/security pair
(real per-repo API setters, no config file) is unambiguous: on for the
mirror, actively deleted elsewhere.

### SOURCE half is DECLARATIVE, not enforced

The bot is `role=member` on both SOURCE orgs, and `SOURCE_ORGS` is
commented out of the `ORGS` array in `dm-github-org-policy` pending an
admin token:

- `--apply` never reaches Kicksecure / Whonix.
- `--dry-run` / `--audit` reach them only via
  `ORGS_OVERRIDE='Kicksecure,Whonix'`.
- Deleting version configs is 13 pull requests an owner must merge,
  not an API call, even with an admin token.

So the SOURCE half is the desired state an owner can act on plus the
measurement of how far live state is from it -- not a claim they match.
The MIRROR and PROJECT halves are enforced on every `--apply`.

### Measured SOURCE inventory (2026-07-31)

124 repos (Kicksecure 93, Whonix 31). Exactly 15 carry
`.github/dependabot.yml`, zero carry a `.yaml` variant:

- Kicksecure: developer-meta-files, msgcollector, helper-scripts,
  tb-updater, usability-misc, security-misc, genmkfile,
  derivative-maker, grml-debootstrap, hardened_malloc (ARCHIVED),
  mediawiki-extensions-Kicksecure (ARCHIVED)
- Whonix: whonix-firewall, kloak, derivative-maker, Whonix-Installer

Most are the github-actions (+docker) weekly template. Outliers:
`hardened_malloc` sets `target-branch: main` on a repo with no `main`
branch (inert); `mediawiki-extensions-Kicksecure` is the only
composer/npm config (daily). The two ARCHIVED repos must be un-archived
before their configs can be deleted (Dependabot does not run on an
archived repo, and `--audit` does not enumerate archived repos).

`security_and_analysis` was NOT READABLE with the bot token on any of
the 124 repos (403/404 wall), so per-repo alert/security state on
SOURCE is UNKNOWN and audited as NOT VERIFIED.

### Sequencing: do not disable SOURCE first

Disabling Dependabot on SOURCE also stops the mechanism that retires
open SOURCE bump PRs (Dependabot closes its own PR once the dependency
is already at the new version upstream). Cheaper order: let the
mirror-side bumps land upstream, let the SOURCE copies retire
themselves, then disable.

### What `--audit` compares

Drift is a finding; an endpoint that could not be read is also a
finding (an unread endpoint is never a pass):

- MIRROR: security updates must read `enabled: true`
  (`GET /automated-security-fixes`) vs
  `POLICY_REPO_DEPENDABOT_FIXES_EXPECT_ON`; alerts must read enabled
  (`GET /vulnerability-alerts` -> HTTP 204).
- SOURCE + PROJECT + STAGE: security updates must read `enabled: false`
  vs `POLICY_REPO_DEPENDABOT_FIXES_EXPECT_OFF`. The member token
  answers 404 on SOURCE, reported as NOT VERIFIED.
- SOURCE + STAGE: `.github/dependabot.yml` must be ABSENT; present is
  drift. On MIRROR + PROJECT a present file is a verifiable opt-in.
- Every kind, MIRROR included: a `dependabot.yml` probe answering
  neither 200 nor 404 is NOT VERIFIED. Reading "could not tell" as
  "absent" is the exact false green this audit exists to prevent.

Deliberately NOT compared, stated rather than implied:

- The "alerts off" claim on SOURCE / PROJECT cannot be verified:
  `GET /vulnerability-alerts` answers 404 both when alerts are off and
  when the token cannot see the repo, so a must-be-OFF assertion is
  indistinguishable from a permissions wall. Only the must-be-ON
  direction is asserted, on MIRROR.
- Per-repo non-Dependabot settings (repo PATCH body, PVR, rulesets) are
  applied but not compared. Pre-existing gap.

## UI-only operator flips

Settings whose desired state is known but which have no documented REST
setter as of 2026-05. `--apply` / `--dry-run` emits a `skip: ... see
<URL>` line on each affected org/repo so the operator can finish the
flip in the UI. Each is emitted only where its subject exists.

| Setting | Scope | Emitted on | Desired | Moot elsewhere because |
| --- | --- | --- | --- | --- |
| Dependabot grouped security updates | org | MIRROR | on | Dependabot off elsewhere; no PRs to group |
| Code scanning: recommend security-extended query suite | org | SOURCE | on | MIRROR uses the reusable `codeql.yml` (advanced setup, own `queries:`) |
| Auto-triage "Dismiss low-impact dev-scoped" | repo | MIRROR | off | alerts off elsewhere |
| Auto-triage "Dismiss package malware alerts" | repo | MIRROR | off | alerts off elsewhere; malware is highest-signal, never auto-dismiss |
| Delegated alert dismissal ("Prevent direct dismissals") | repo | MIRROR | on | alerts off elsewhere |
| Dependabot version updates (delete `.github/dependabot.yml`) | repo | SOURCE, STAGE | off | not a UI flip but a commit; listed for its "no REST setter" shape |

- **Grouped security updates**: one PR per ecosystem + directory
  instead of one per vulnerable dep; prefer the org-level flip as the
  single source of truth (per-repo `groups:` blocks still override).
- **Extended query suite recommendation**: nudges new opt-ins toward
  broader coverage; no effect on repos using advanced setup with an
  explicit `queries:`.
- **Delegated alert dismissal**: write-access contributors must request
  dismissal; owners / security managers approve.

## Potential future tightenings (not in policy yet)

Surfaced in the 2026-05 web-settings sweep; each is low-risk, gated on
operator appetite for the friction.

- **`web_commit_signoff_required: true`** (org or per-repo): forces a
  `Signed-off-by:` DCO trailer (https://developercertificate.org/) on
  web-UI commits. Not GPG, not security. Worth it only if Kicksecure /
  Whonix adopts the DCO sign-off model. The cryptographic-signature
  requirement is the separate `required_signatures` rule, which web-UI
  commits already satisfy via GitHub's web-flow GPG key.
- **Tag-name pattern ruleset rule** (e.g. `^v[0-9]+\.[0-9]+(\.[0-9]+)?$`):
  catches wrong-format tag pushes. May need a hotfix-tag bypass.
- **`interaction_limit: collaborators_only`** on MIRROR
  (`PUT /interaction-limits`): a hostile drive-by PR is silently
  rejected by the API instead of opening a noisy issue.
- **Audit flag for private repos** in `audit_org_state`: none exist
  today, but flipping a public repo private via the UI silently breaks
  secret scanning + push protection (GHAS is required for those on
  private Free-org repos). Read-only check.
- **Org Copilot `public_code_suggestions: block`** (currently
  `allow`): moot at 0 seats, but blocking verbatim public-code
  suggestions reduces the risk of GPL / BSD snippets landing without
  attribution once a seat is assigned.
- **GitHub Code Quality** (CodeQL quality suite, public preview
  2025-10-28): fires on PR diffs + default branch, so it lands where
  the PRs are -- the MIRROR-only conclusion Dependabot reaches, for the
  same reason.

  | Role | Code Quality | Why |
  | --- | --- | --- |
  | SOURCE | blocked | needs Actions, disabled org-wide |
  | MIRROR | on | PR-time feedback where AI-assisted PRs land; `dm-github-org-security-report` already routes alerts here |
  | PERSON | off | no PRs land here |
  | BOT | off | no PRs land here; Actions disabled |

  The `require_code_quality_results` ruleset rule (with a `Severity`
  threshold) belongs on SOURCE only; enforcing it on MIRROR would block
  the AI's own iteration loop. Per-repo enable is UI-only today
  (`https://github.com/<owner>/<repo>/settings/code-quality`).

`sha_pinning_required: true` is intentionally NOT in this list -- see
`agents/github-actions.md` "Org-level `sha_pinning_required` is
intentionally OFF".
