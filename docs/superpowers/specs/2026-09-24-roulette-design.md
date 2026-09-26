# roulette — Design

**Date:** 2026-09-24
**Status:** Approved (v3 — auto-detected usernames)

## Problem

Individual developers who hold more than one Claude subscription lose time
switching accounts in Claude Code: logging out, logging in, and losing the
thread of the conversation they were in when a usage limit hit. The goal is to
make switching between one's own accounts take seconds, keep conversation
context across the switch, and show which account has room left.

## Goals

- Onboard an account once; never re-authenticate on switch.
- Resume the current conversation on another account with one command.
- Show per-account 5-hour and 7-day usage from Claude Code's own data.
- New user fully set up in about two minutes.
- Small enough to audit in one sitting.

## Non-goals

- **No automatic switching.** roulette recommends; the user always runs the
  switch. It never swaps accounts in the background or on a limit event.
- No Claude.ai web or desktop app support — Claude Code CLI only.
- No API-key / pay-per-token account management.
- No team or shared-account features.

## Architecture

A single POSIX shell script `roulette` installed to `~/.local/bin`, with an
alias `rt`. Only runtime dependency beyond the OS: `jq`.

### Credentials

- Each account is a long-lived token produced by the user running
  `claude setup-token` while signed in to that account.
- Tokens are stored in the macOS Keychain as generic passwords, service
  `roulette:<name>`, account `$USER`.
- All keychain access goes through two functions, `secret_get <name>` and
  `secret_set <name>` (plus `secret_del`). Linux support later means
  implementing these against `secret-tool`; nothing else changes.
- Tokens are never written to disk by roulette, never logged, and passed only
  as the environment of the `claude` child process.

### Launch

`roulette use <name> [claude args...]`:

```
CLAUDE_CODE_OAUTH_TOKEN=$(secret_get name) ROULETTE_ACCOUNT=name exec claude "$@"
```

All accounts share the single `~/.claude` directory, so settings, skills,
plugins, memory and project history are common to every account and
`claude --continue` resumes across accounts.

### Commands

| Command | Behavior |
|---|---|
| `roulette add <name>` | Prints instructions to run `claude setup-token` for the target account, reads the token from a hidden prompt, stores it, then auto-detects and stores the account's real username (see Account identity). Refuses to overwrite without `--force`. |
| `roulette use <name> [args]` | Launch Claude Code on that account (above). |
| `roulette next [args]` | Rank accounts (see Ranking), print the table (with usernames), preselect the best, wait for Enter, a typed name, or a number, then `use <choice> --continue [args]`. |
| `roulette status` | Table: account, username, 5h %, 7d %, snapshot age, estimated state. |
| `roulette list` | Account names with usernames. |
| `roulette remove <name>` | Delete keychain entry and state for that account. |
| `roulette refresh <name>` | Re-run username detection for an account (e.g. after the user changes their email on that account). |
| `roulette statusline-hook [-- cmd...]` | Status line integration (see Usage tracking). |

### Account identity

roulette identifies accounts to the user by their real login, not an
invented label. Purpose: accounts differ by more than quota — different org
memberships, different tool/data access (e.g. one account with cybersecurity
tool access, others scoped to a client org) — so the user needs to pick by
who that account actually is, not just by headroom, and a label typed once
can drift or be forgotten while the account's own identity can't.

Immediately after a token is stored, `add` runs
`CLAUDE_CODE_OAUTH_TOKEN=<token> claude auth status --json` and extracts the
account's email (exact JSON field TBD — see Open items). The result is stored
as that account's `username` and shown by `list`, `status`, and `next` next
to the short local name:

```
  acct1   you+sec@example.com   5h 24%  7d 41%
  acct2   you@client-a.test     5h 88%  7d 52%
* acct3   you@client-b.test     5h  3%  7d 12%
```

If detection fails (unexpected JSON shape, command error), `add` still
succeeds — the account is usable — but stores `username: null` and `list`
shows `(unknown — run 'roulette refresh <name>')`. Detection never blocks
`add` or `use`.

### State

`${XDG_CONFIG_HOME:-~/.config}/roulette/state.json`:

```json
{
  "accounts": ["acct1", "acct2", "acct3"],
  "usernames": {
    "acct2": "you+sec@example.com"
  },
  "usage": {
    "acct2": { "five_hour": 41, "seven_day": 63, "resets_at": null, "seen": 1790000000 }
  }
}
```

No secrets in this file. All writes go to a temp file in the same directory
followed by `mv` (atomic rename), so concurrent sessions cannot corrupt it.

## Usage tracking

Claude Code passes a JSON payload to the configured status line command. That
payload includes `rate_limits.five_hour.used_percentage` and
`rate_limits.seven_day.used_percentage` (confirmed in a working status line
script). Whether it includes reset timestamps is unverified; `resets_at` is
populated if present, otherwise null.

`roulette statusline-hook` reads the payload from stdin and, if
`ROULETTE_ACCOUNT` is set, writes a usage snapshot for that account. Two modes:

- **Standalone:** prints `[acct] 5h ▰▰▱▱ 41% · 7d ▰▰▰▱ 63%`.
- **Chained:** `roulette statusline-hook -- <existing command>` pipes the same
  payload to the user's existing status line command, prints its output, and
  appends `[acct]`. Existing status lines keep working unchanged.

If the payload has no `rate_limits`, no snapshot is written and output is
unaffected.

### Staleness

A snapshot reflects the last time that account ran. `status` shows its age.
When a snapshot is older than 5 hours (and `resets_at` is null or past), the
5h value is displayed as `~0% (est. reset)`. The 7-day value is estimated the
same way after 7 days. Estimates are always labeled as such.

### Ranking (`next`)

1. Exclude the currently active account (`ROULETTE_ACCOUNT` if set; otherwise the account `use` launched last, stored as `last` in state).
2. Exclude accounts whose effective 7d usage is ≥ 100%.
3. Sort by effective 5h usage ascending; ties broken by oldest snapshot.
4. Accounts with no snapshot rank after all accounts with known headroom
   under 50% and before all others.
5. If every account is excluded, print the soonest estimated reset and exit
   non-zero without launching.

## Error handling

| Condition | Behavior |
|---|---|
| `jq` missing | Print install hint, exit 1. |
| Unknown account | List valid names, exit 1. |
| No accounts configured | Point to `roulette add`, exit 1. |
| Keychain entry missing for a listed account | Say so, suggest `roulette add <name> --force`. |
| Token rejected by Claude Code | Claude's own error is shown; roulette's `use` prints a one-line hint to re-add the account when `claude` exits non-zero within 5 seconds. |
| All accounts exhausted | See Ranking step 5. |

roulette never retries a launch on another account automatically.

## Testing

- `bats` suite with fakes on `PATH`:
  - fake `security` backed by a temp directory (keychain)
  - fake `claude` that records its env and args
- Covered: add/use/remove round-trip, token never appears in state or output,
  username detection (success, unexpected JSON, command failure → null),
  snapshot parsing from sample payloads (with and without `rate_limits`),
  staleness estimation, ranking order and edge cases, atomic writes under
  parallel hook invocations, chained status line passthrough.
- CI (GitHub Actions, macOS runner): `shellcheck` + `bats`.
- Manual release check: two real accounts, limit a session, `roulette next`,
  confirm conversation resumes with context.

## Repository layout

```
roulette/
  roulette                 # the script
  install.sh               # copies script, creates rt alias, checks jq
  test/                    # bats tests + fakes
  docs/superpowers/specs/  # this document
  README.md                # setup, how tokens are stored, non-goals
  LICENSE                  # MIT
  .github/workflows/ci.yml
```

## README commitments

- State plainly where tokens live and that roulette only hands them to the
  local `claude` process.
- State the non-goal: switching is always manual; roulette is for people using
  their own subscriptions, not for pooling or evading usage limits.
- Name is independent of Anthropic; no Claude trademark in the project name.

## Open items to verify during implementation

- Whether the status line payload includes reset timestamps.
- RESOLVED 2026-09-26: with a `setup-token` token, `claude auth status --json`
  returns only `loggedIn`, `authMethod`, `apiProvider`, `projectsDirectory`,
  `configDirectory` — no email. `add` now prompts for the email when detection
  finds none (detection is kept in case a later Claude Code adds it).
- (original) Which field of `claude auth status --json` holds the account email, and
  whether it honors `CLAUDE_CODE_OAUTH_TOKEN` (vs. reading the stored login).
  If it does not honor the env var, fall back to prompting the user for the
  username at `add` time.
- Exact Claude Code behavior on an invalid `CLAUDE_CODE_OAUTH_TOKEN` (exit
  code, timing) to tune the re-add hint.

## Considered and rejected

- **Automatic account switching** (e.g. an unattended job hopping to the next
  account when one hits its 5h/7d limit, including a wait-for-reset-then-relaunch
  mode): rejected. roulette only ever switches accounts when the user runs a
  command. This was discussed explicitly and the user agreed; unattended
  multi-account rotation belongs on the API (no 5h/7d windows), not on
  subscription accounts. Do not reintroduce without a fresh design
  conversation.

## Future: other providers (v2, not in scope for v1)

Raised during planning. Candidates and fit:

- **Kimi (Moonshot)** — Anthropic-compatible endpoint, so it runs *inside
  Claude Code* via `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN`. Closest fit:
  an account gains a `provider` field and `use` sets different env vars.
  `--continue` keeps working since it is still Claude Code.
- **Codex CLI, Gemini CLI** — separate CLIs with their own auth, config dirs
  and session stores. Account switching is feasible per CLI; conversation
  continuity across CLIs is not (`--continue` is per-CLI) and would need a
  separate handoff-summary feature.
- Each provider's terms on multiple accounts must be checked before support
  is advertised.

v1 keeps all launch logic in one function (`launch_account`) so a provider
field is a contained change.
