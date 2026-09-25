load helper

@test "help lists commands" {
  run "$RT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"roulette use <name>"* ]] || false
  [[ "$output" == *"roulette next"* ]] || false
}

@test "no arguments prints help" {
  run "$RT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"roulette add <name>"* ]] || false
}

@test "unknown command fails with help on stderr" {
  run "$RT" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown command: frobnicate"* ]] || false
}

@test "list with no accounts points to add" {
  run "$RT" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"no accounts yet"* ]] || false
}

@test "list shows accounts, usernames and marks the current one" {
  write_state '{"accounts":["a","b"],"usernames":{"a":"a@x.com","b":null},"usage":{}}'
  ROULETTE_ACCOUNT=a run "$RT" list
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "* a"*"a@x.com" ]] || false
  [[ "${lines[1]}" == "  b"*"(unknown)" ]] || false
}

@test "corrupt state file is reported, not overwritten" {
  write_state 'not json{'
  run "$RT" list
  [ "$status" -eq 1 ]
  [[ "$output" == *"state file is corrupt"* ]] || false
  [ "$(cat "$ROULETTE_CONFIG_DIR/state.json")" = 'not json{' ]
}
