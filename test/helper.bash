setup() {
  export ROULETTE_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
  export FAKE_KEYCHAIN="$BATS_TEST_TMPDIR/keychain"
  export FAKE_CLAUDE_LOG="$BATS_TEST_TMPDIR/claude.log"
  mkdir -p "$FAKE_KEYCHAIN"
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export USER=tester
  unset ROULETTE_ACCOUNT ROULETTE_NOW ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
  unset FAKE_AUTH_JSON FAKE_AUTH_FAIL FAKE_CLAUDE_EXIT
  RT="$BATS_TEST_DIRNAME/../roulette"
}

# add_account <name> <token>
add_account() {
  printf '%s\n' "$2" | "$RT" add "$1" >/dev/null 2>&1
}

# write_state <json>
write_state() {
  mkdir -p "$ROULETTE_CONFIG_DIR"
  printf '%s\n' "$1" > "$ROULETTE_CONFIG_DIR/state.json"
}

# email_for <token> — what the fake claude reports for that token
email_for() {
  printf 'user-%s@example.com' "$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
}
