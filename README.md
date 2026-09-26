# roulette

Switch Claude Code between **your own** subscription accounts in seconds —
no logging out and back in, and your conversation comes with you.

```
$ rt next
1) org2   you@client-b.com   5h ▱▱▱▱▱▱▱▱   3%   7d ▰▱▱▱▱▱▱▱  12%
2) cyber  you+sec@you.dev    5h ▰▰▱▱▱▱▱▱  24%   7d ▰▰▰▱▱▱▱▱  41%
Switch to [org2]:
```

## Install

Needs macOS, [jq](https://jqlang.github.io/jq/) and Claude Code.

```sh
git clone https://github.com/tikket1/roulette && cd roulette && ./install.sh
```

This puts `roulette` and the shortcut `rt` in `~/.local/bin`.

## Add your accounts

For each account:

```sh
rt add work
```

roulette asks you to run `claude setup-token` in another terminal and sign in
as that account (a private browser window per account avoids mix-ups), then
paste the token. It then asks for that account's login email, so `rt list` and
`rt status` always show which account is which — Claude Code doesn't reveal
the email for token logins, so roulette can't look it up itself.

## Use

| Command | |
|---|---|
| `rt use work` | Start Claude Code on `work` |
| `rt next` | Pick another account and continue your last conversation there |
| `rt status` | Each account's login, 5-hour and 7-day usage, and how fresh that is |
| `rt list` | Accounts and logins |
| `rt refresh work [email]` | Re-detect a login, or set it by hand if detection gets it wrong |
| `rt remove work` | Forget an account |

Everything after the account name is passed to `claude`, e.g. `rt use work --model sonnet`.

All accounts share your normal `~/.claude` — settings, skills, plugins, memory
and history — which is why `rt next` can pick up the conversation where you
left it.

## Usage in your status line

roulette learns each account's usage from Claude Code's status line. In
`~/.claude/settings.json`, either use roulette's own status line:

```json
"statusLine": { "type": "command", "command": "roulette statusline-hook" }
```

or keep yours and let roulette tag along:

```json
"statusLine": { "type": "command", "command": "roulette statusline-hook -- node ~/.claude/hooks/statusline.js" }
```

Usage for an account is only as fresh as the last time you used it; `rt status`
shows how old each number is and marks estimated resets with `~`.

## Where your tokens go

- Each token is stored in the macOS Keychain as `roulette:<name>`.
- roulette hands it only to the `claude` process it starts, as
  `CLAUDE_CODE_OAUTH_TOKEN`. It never writes it to a file, prints it, or sends
  it anywhere.
- `~/.config/roulette/state.json` holds account names, login emails and usage
  percentages — nothing secret.

## What roulette does not do

roulette only switches accounts when **you** run a command. It does not rotate
accounts automatically, run unattended work across accounts, or help get
around usage limits. It is for people using their own subscriptions by hand.
For unattended, around-the-clock workloads, use the Claude API.

roulette is an independent project, not affiliated with Anthropic.

## Develop

```sh
brew install bats-core shellcheck
bats test/ && shellcheck -s sh roulette install.sh
```

Tests run under macOS's bash 3.2, where a failing `[[ … ]]` in the middle of a
test does not fail it — write those assertions as `[[ … ]] || false`.
