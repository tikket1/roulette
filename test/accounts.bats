load helper

@test "add stores the token in the keychain and the name in state" {
  run bash -c "printf 'tok-a\n' | '$RT' add a"
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_KEYCHAIN/roulette_a")" = "tok-a" ]
  [ "$(jq -c .accounts "$ROULETTE_CONFIG_DIR/state.json")" = '["a"]' ]
}

@test "add detects and prints the account's login" {
  run bash -c "printf 'tok-a\n' | '$RT' add a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"a → $(email_for tok-a)"* ]] || false
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "$(email_for tok-a)" ]
}

@test "add reads the email from a nested account object" {
  export FAKE_AUTH_JSON='{"loggedIn":true,"account":{"email":"nested@x.com"}}'
  add_account a tok-a
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "nested@x.com" ]
}

@test "add succeeds with unknown username when detection fails" {
  export FAKE_AUTH_FAIL=1
  run bash -c "printf 'tok-a\n' | '$RT' add a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(unknown — run 'roulette refresh a'"* ]] || false
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "null" ]
}

@test "add succeeds with unknown username on unexpected JSON" {
  export FAKE_AUTH_JSON='{"something":"else"}'
  add_account a tok-a
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "null" ]
}

@test "warns when two accounts report the same login" {
  export FAKE_AUTH_JSON='{"email":"same@x.com"}'
  add_account a tok-a
  run bash -c "printf 'tok-b\n' | '$RT' add b"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: 'b' reports the same login as 'a'"* ]] || false
}

@test "trims whitespace from pasted token" {
  run bash -c "printf '  tok-a \r\n' | '$RT' add a"
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_KEYCHAIN/roulette_a")" = "tok-a" ]
}

@test "token is never printed, stored in state, or passed as an argument" {
  run bash -c "printf 'sk-secret-123\n' | '$RT' add a"
  [ "$status" -eq 0 ]
  [[ "$output" != *"sk-secret-123"* ]] || false
  run grep -q "sk-secret-123" "$ROULETTE_CONFIG_DIR/state.json"
  [ "$status" -eq 1 ]
  run grep -q "sk-secret-123" "$FAKE_KEYCHAIN/.argv"
  [ "$status" -eq 1 ]
}

@test "rejects invalid account names" {
  run bash -c "printf 'tok\n' | '$RT' add 'bad name'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"may only use letters, digits"* ]] || false
}

@test "rejects an empty token" {
  run bash -c "printf '\n' | '$RT' add a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no token entered"* ]] || false
}

@test "refuses to overwrite an existing account without --force" {
  add_account a tok-a
  run bash -c "printf 'tok-new\n' | '$RT' add a"
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]] || false
  [ "$(cat "$FAKE_KEYCHAIN/roulette_a")" = "tok-a" ]
}

@test "--force replaces the token without duplicating the account" {
  add_account a tok-a
  run bash -c "printf 'tok-new\n' | '$RT' add a --force"
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_KEYCHAIN/roulette_a")" = "tok-new" ]
  [ "$(jq -c .accounts "$ROULETTE_CONFIG_DIR/state.json")" = '["a"]' ]
}

@test "remove deletes keychain entry and all state for the account" {
  add_account a tok-a
  add_account b tok-b
  run "$RT" remove a
  [ "$status" -eq 0 ]
  [ ! -f "$FAKE_KEYCHAIN/roulette_a" ]
  [ "$(jq -c '[.accounts, (.usernames | keys)]' "$ROULETTE_CONFIG_DIR/state.json")" = '[["b"],["b"]]' ]
}

@test "remove of unknown account lists valid ones" {
  add_account a tok-a
  run "$RT" remove zzz
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown account 'zzz'. Accounts: a"* ]] || false
}

@test "refresh re-detects the login" {
  export FAKE_AUTH_FAIL=1
  add_account a tok-a
  unset FAKE_AUTH_FAIL
  run "$RT" refresh a
  [ "$status" -eq 0 ]
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "$(email_for tok-a)" ]
}

@test "refresh with missing keychain entry suggests re-adding" {
  add_account a tok-a
  rm "$FAKE_KEYCHAIN/roulette_a"
  run "$RT" refresh a
  [ "$status" -eq 1 ]
  [[ "$output" == *"roulette add a --force"* ]] || false
}

@test "refresh with an email sets the login by hand" {
  export FAKE_AUTH_FAIL=1
  add_account a tok-a
  run "$RT" refresh a me@x.com
  [ "$status" -eq 0 ]
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "me@x.com" ]
}

@test "duplicate-login warning explains how to set the login by hand" {
  export FAKE_AUTH_JSON='{"email":"same@x.com"}'
  add_account a tok-a
  run bash -c "printf 'tok-b\n' | '$RT' add b"
  [[ "$output" == *"roulette refresh b <email>"* ]] || false
}

@test "unknown login message explains how to set it by hand" {
  export FAKE_AUTH_FAIL=1
  run bash -c "printf 'tok-a\n' | '$RT' add a"
  [[ "$output" == *"roulette refresh a <email>"* ]] || false
}

@test "add asks for the login email when it can't be detected" {
  export FAKE_AUTH_JSON='{"loggedIn":true,"authMethod":"oauth_token"}'
  run bash -c "printf 'tok-a\nme@x.com\n' | '$RT' add a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Login email for 'a'"* ]] || false
  [[ "$output" == *"a → me@x.com"* ]] || false
  [ "$(jq -r '.usernames.a' "$ROULETTE_CONFIG_DIR/state.json")" = "me@x.com" ]
}

@test "add does not ask for the email when it was detected" {
  run bash -c "printf 'tok-a\n' | '$RT' add a"
  [[ "$output" != *"Login email for"* ]] || false
}
