load helper

@test "whoami inside a roulette session shows the account and login" {
  write_state '{"accounts":["org1"],"usernames":{"org1":"me@org1.com"},"usage":{}}'
  ROULETTE_ACCOUNT=org1 CLAUDE_CODE_OAUTH_TOKEN=tok run "$RT" whoami
  [ "$status" -eq 0 ]
  [ "$output" = "org1  me@org1.com" ]
}

@test "whoami outside roulette with an API key says so" {
  ANTHROPIC_API_KEY=sk-x run "$RT" whoami
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a roulette session"*"ANTHROPIC_API_KEY"* ]] || false
}

@test "whoami outside roulette with no overrides reports the normal login" {
  run "$RT" whoami
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a roulette session"*"normal login"* ]] || false
}

@test "whoami never prints the token" {
  write_state '{"accounts":["org1"],"usernames":{},"usage":{}}'
  ROULETTE_ACCOUNT=org1 CLAUDE_CODE_OAUTH_TOKEN=sk-secret-123 run "$RT" whoami
  [[ "$output" != *"sk-secret-123"* ]] || false
}
