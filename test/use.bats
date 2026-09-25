load helper

@test "use launches claude with the account's token and label" {
  add_account a tok-a
  run "$RT" use a
  [ "$status" -eq 0 ]
  grep -qx 'token=tok-a' "$FAKE_CLAUDE_LOG"
  grep -qx 'account=a' "$FAKE_CLAUDE_LOG"
}

@test "use passes claude arguments through intact" {
  add_account a tok-a
  run "$RT" use a --continue -p "two words"
  grep -qx 'arg=--continue' "$FAKE_CLAUDE_LOG"
  grep -qx 'arg=-p' "$FAKE_CLAUDE_LOG"
  grep -qx 'arg=two words' "$FAKE_CLAUDE_LOG"
}

@test "use clears API key env vars so the account token is what gets used" {
  add_account a tok-a
  ANTHROPIC_API_KEY=sk-api ANTHROPIC_AUTH_TOKEN=other run "$RT" use a
  grep -qx 'apikey=' "$FAKE_CLAUDE_LOG"
  grep -qx 'authtoken=' "$FAKE_CLAUDE_LOG"
}

@test "use returns claude's exit code" {
  add_account a tok-a
  FAKE_CLAUDE_EXIT=3 run "$RT" use a
  [ "$status" -eq 3 ]
}

@test "use hints at re-adding when claude fails immediately" {
  add_account a tok-a
  FAKE_CLAUDE_EXIT=1 run "$RT" use a
  [ "$status" -eq 1 ]
  [[ "$output" == *"re-add it with: roulette add a --force"* ]] || false
}

@test "use of unknown account fails without launching" {
  add_account a tok-a
  run "$RT" use zzz
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown account 'zzz'"* ]] || false
  [ ! -f "$FAKE_CLAUDE_LOG" ]
}

@test "use with missing keychain entry fails without launching" {
  add_account a tok-a
  rm "$FAKE_KEYCHAIN/roulette_a"
  run "$RT" use a
  [ "$status" -eq 1 ]
  [[ "$output" == *"no keychain entry for 'a'"* ]] || false
  [ ! -f "$FAKE_CLAUDE_LOG" ]
}

@test "use never prints the token" {
  add_account a sk-secret-123
  FAKE_CLAUDE_EXIT=1 run "$RT" use a
  [ "$status" -eq 1 ]
  [[ "$output" != *"sk-secret-123"* ]] || false
}
