load helper

@test "install copies roulette and creates the rt shortcut" {
  run "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_TMPDIR/bin"
  [ "$status" -eq 0 ]
  [ -x "$BATS_TEST_TMPDIR/bin/roulette" ]
  [ -L "$BATS_TEST_TMPDIR/bin/rt" ]
  run "$BATS_TEST_TMPDIR/bin/rt" --version
  [[ "$output" == "roulette "* ]] || false
}
