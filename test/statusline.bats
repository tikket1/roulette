load helper

payload() {  # payload <five> <seven>
  printf '{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":%s},"seven_day":{"used_percentage":%s}}}' "$1" "$2"
}

@test "records a usage snapshot for the current account" {
  add_account a tok-a
  export ROULETTE_NOW=1000
  run bash -c "$(declare -f payload); payload 41 63 | ROULETTE_ACCOUNT=a '$RT' statusline-hook"
  [ "$status" -eq 0 ]
  [ "$(jq -c .usage.a "$ROULETTE_CONFIG_DIR/state.json")" = '{"five_hour":41,"seven_day":63,"resets_at":null,"seen":1000}' ]
}

@test "keeps a numeric reset time when the payload has one" {
  add_account a tok-a
  printf '{"rate_limits":{"five_hour":{"used_percentage":5,"resets_at":1234},"seven_day":{"used_percentage":6}}}' |
    ROULETTE_ACCOUNT=a "$RT" statusline-hook >/dev/null
  [ "$(jq -r .usage.a.resets_at "$ROULETTE_CONFIG_DIR/state.json")" = "1234" ]
}

@test "standalone output shows account and usage bars" {
  add_account a tok-a
  run bash -c "$(declare -f payload); payload 50 25 | ROULETTE_ACCOUNT=a '$RT' statusline-hook"
  [ "$output" = "[a] 5h ▰▰▰▰▱▱▱▱ 50% · 7d ▰▰▱▱▱▱▱▱ 25%" ]
}

@test "no rate_limits: no snapshot, label only" {
  add_account a tok-a
  run bash -c "printf '{\"model\":{}}' | ROULETTE_ACCOUNT=a '$RT' statusline-hook"
  [ "$status" -eq 0 ]
  [ "$output" = "[a]" ]
  [ "$(jq -c .usage "$ROULETTE_CONFIG_DIR/state.json")" = '{}' ]
}

@test "outside a roulette session nothing is recorded" {
  add_account a tok-a
  run bash -c "$(declare -f payload); payload 41 63 | '$RT' statusline-hook"
  [ "$status" -eq 0 ]
  [ "$(jq -c .usage "$ROULETTE_CONFIG_DIR/state.json")" = '{}' ]
}

@test "unknown account in env is not recorded" {
  add_account a tok-a
  run bash -c "$(declare -f payload); payload 41 63 | ROULETTE_ACCOUNT=ghost '$RT' statusline-hook"
  [ "$status" -eq 0 ]
  [ "$(jq -c .usage "$ROULETTE_CONFIG_DIR/state.json")" = '{}' ]
}

@test "chained mode passes the payload to the existing command and appends the label" {
  add_account a tok-a
  run bash -c "$(declare -f payload); payload 41 63 | ROULETTE_ACCOUNT=a '$RT' statusline-hook -- jq -r .model.display_name"
  [ "$status" -eq 0 ]
  [ "$output" = "Opus [a]" ]
}

@test "chained mode outside a session is a pure passthrough" {
  run bash -c "$(declare -f payload); payload 41 63 | '$RT' statusline-hook -- jq -r .model.display_name"
  [ "$output" = "Opus" ]
}

@test "malformed payload still prints chained output and exits 0" {
  add_account a tok-a
  run bash -c "printf 'not json' | ROULETTE_ACCOUNT=a '$RT' statusline-hook -- echo MYLINE"
  [ "$status" -eq 0 ]
  [ "$output" = "MYLINE [a]" ]
}

@test "corrupt state still prints chained output and exits 0" {
  write_state 'garbage'
  run bash -c "$(declare -f payload); payload 1 1 | ROULETTE_ACCOUNT=a '$RT' statusline-hook -- echo MYLINE"
  [ "$status" -eq 0 ]
  [[ "$output" == "MYLINE"* ]] || false
}

@test "parallel hook runs leave valid state" {
  add_account a tok-a
  add_account b tok-b
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf '{"rate_limits":{"five_hour":{"used_percentage":%s},"seven_day":{"used_percentage":1}}}' "$i" |
      ROULETTE_ACCOUNT=a "$RT" statusline-hook >/dev/null &
  done
  wait
  run jq -e '.accounts == ["a","b"] and (.usage.a.five_hour | type == "number")' "$ROULETTE_CONFIG_DIR/state.json"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$ROULETTE_CONFIG_DIR" | grep '^\.state\.')" ]
}

@test "parallel hook runs from different accounts lose no updates" {
  for n in a b c d e f g h; do add_account "$n" "tok-$n"; done
  for n in a b c d e f g h; do
    printf '{"rate_limits":{"five_hour":{"used_percentage":5},"seven_day":{"used_percentage":1}}}' |
      ROULETTE_ACCOUNT=$n "$RT" statusline-hook >/dev/null &
  done
  wait
  [ "$(jq -c '.usage | keys' "$ROULETTE_CONFIG_DIR/state.json")" = '["a","b","c","d","e","f","g","h"]' ]
}

@test "non-numeric percentages are stored as unknown" {
  add_account a tok-a
  printf '{"rate_limits":{"five_hour":{"used_percentage":"41"},"seven_day":{"used_percentage":7}}}' |
    ROULETTE_ACCOUNT=a "$RT" statusline-hook >/dev/null
  [ "$(jq -c '[.usage.a.five_hour, .usage.a.seven_day]' "$ROULETTE_CONFIG_DIR/state.json")" = '[null,7]' ]
  run "$RT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"a "*"7%"* ]] || false
}
