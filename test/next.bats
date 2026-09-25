load helper

# Three accounts with keychain entries; usage set per test via set_usage.
three_accounts() {
  add_account a tok-a
  add_account b tok-b
  add_account c tok-c
}

set_usage() {  # set_usage <usage-json>
  jq -c --argjson u "$1" '.usage = $u' "$ROULETTE_CONFIG_DIR/state.json" > "$BATS_TEST_TMPDIR/s"
  mv "$BATS_TEST_TMPDIR/s" "$ROULETTE_CONFIG_DIR/state.json"
}

@test "status shows each account with login, usage and age" {
  three_accounts
  export ROULETTE_NOW=10000
  set_usage '{"a":{"five_hour":24,"seven_day":41,"resets_at":null,"seen":9880}}'
  run "$RT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"a "*"$(email_for tok-a)"*"24%"*"41%"*"2m ago"* ]] || false
  [[ "$output" == *"b "*"$(email_for tok-b)"*"?"*"never"* ]] || false
}

@test "status marks estimated resets for old snapshots" {
  three_accounts
  export ROULETTE_NOW=100000
  set_usage '{"a":{"five_hour":90,"seven_day":41,"resets_at":null,"seen":1000}}'
  run "$RT" status
  [[ "$output" == *"0%~"* ]] || false
  [[ "$output" == *"~ estimated"* ]] || false
}

@test "status marks the current account" {
  three_accounts
  ROULETTE_ACCOUNT=b run "$RT" status
  [[ "$output" == *"* b "* ]] || false
}

@test "next ranks by 5h headroom and defaults to the best" {
  three_accounts
  export ROULETTE_NOW=10000
  set_usage '{"a":{"five_hour":80,"seven_day":10,"resets_at":null,"seen":9990},
              "b":{"five_hour":10,"seven_day":10,"resets_at":null,"seen":9990},
              "c":{"five_hour":40,"seven_day":10,"resets_at":null,"seen":9990}}'
  run bash -c "printf '\n' | '$RT' next"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "1) b"* ]] || false
  [[ "${lines[1]}" == "2) c"* ]] || false
  [[ "${lines[2]}" == "3) a"* ]] || false
  grep -qx 'account=b' "$FAKE_CLAUDE_LOG"
  grep -qx 'arg=--continue' "$FAKE_CLAUDE_LOG"
}

@test "next puts accounts with no data after low-usage and before high-usage ones" {
  three_accounts
  export ROULETTE_NOW=10000
  set_usage '{"a":{"five_hour":70,"seven_day":10,"resets_at":null,"seen":9990},
              "c":{"five_hour":20,"seven_day":10,"resets_at":null,"seen":9990}}'
  run bash -c "printf '\n' | '$RT' next"
  [[ "${lines[0]}" == "1) c"* ]] || false
  [[ "${lines[1]}" == "2) b"* ]] || false
  [[ "${lines[2]}" == "3) a"* ]] || false
}

@test "next excludes the current account" {
  three_accounts
  run bash -c "printf '\n' | ROULETTE_ACCOUNT=a '$RT' next"
  [ "$status" -eq 0 ]
  [[ "$output" != *") a "* ]] || false
  run grep -qx 'account=a' "$FAKE_CLAUDE_LOG"
  [ "$status" -eq 1 ]
}

@test "next excludes accounts at their 7-day limit" {
  three_accounts
  export ROULETTE_NOW=10000
  set_usage '{"b":{"five_hour":0,"seven_day":100,"resets_at":null,"seen":9990}}'
  run bash -c "printf '\n' | '$RT' next"
  [ "$status" -eq 0 ]
  [[ "$output" != *") b "* ]] || false
}

@test "next accepts a number" {
  three_accounts
  run bash -c "printf '2\n' | '$RT' next"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^account=' "$FAKE_CLAUDE_LOG")" -eq 1 ]
  [ "$(sed -n 's/^account=//p' "$FAKE_CLAUDE_LOG")" = "$(printf '%s\n' "$output" | sed -n 's/^2) \([^ ]*\).*/\1/p')" ]
}

@test "next accepts a name" {
  three_accounts
  run bash -c "printf 'c\n' | '$RT' next"
  [ "$status" -eq 0 ]
  grep -qx 'account=c' "$FAKE_CLAUDE_LOG"
}

@test "next rejects a bad number without launching" {
  three_accounts
  run bash -c "printf '9\n' | '$RT' next"
  [ "$status" -eq 1 ]
  [ ! -f "$FAKE_CLAUDE_LOG" ]
}

@test "next passes extra claude args after --continue" {
  three_accounts
  run bash -c "printf '\n' | '$RT' next --model sonnet"
  grep -qx 'arg=--model' "$FAKE_CLAUDE_LOG"
  grep -qx 'arg=sonnet' "$FAKE_CLAUDE_LOG"
}

@test "next with no other accounts explains and does not launch" {
  add_account a tok-a
  run bash -c "printf '\n' | ROULETTE_ACCOUNT=a '$RT' next"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no other accounts"* ]] || false
  [ ! -f "$FAKE_CLAUDE_LOG" ]
}

@test "next with every other account at its 7-day limit shows the soonest reset" {
  three_accounts
  export ROULETTE_NOW=10000
  set_usage '{"b":{"five_hour":0,"seven_day":100,"resets_at":null,"seen":9990},
              "c":{"five_hour":0,"seven_day":100,"resets_at":null,"seen":9000}}'
  run bash -c "printf '\n' | ROULETTE_ACCOUNT=a '$RT' next"
  [ "$status" -eq 1 ]
  [[ "$output" == *"every other account is at its 7-day limit"* ]] || false
  [ ! -f "$FAKE_CLAUDE_LOG" ]
}

@test "next from the parent shell excludes the account last launched" {
  three_accounts
  "$RT" use a
  run bash -c "printf '\n' | '$RT' next"
  [ "$status" -eq 0 ]
  [[ "$output" != *") a "* ]] || false
  [ "$(grep '^account=' "$FAKE_CLAUDE_LOG" | tail -n 1)" != "account=a" ]
}
