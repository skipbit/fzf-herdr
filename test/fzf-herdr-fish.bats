#!/usr/bin/env bats
# Tests for shell/fzf-herdr.fish, loaded after fzf's own fish integration.

bats_require_minimum_version 1.5.0

load helpers

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  command -v fish > /dev/null || skip "fish is not installed"
  # fzf-herdr.fish keeps .. in the path that it adds to PATH.
  fish_file="$(cd "$BATS_TEST_DIRNAME/../shell" && pwd)/fzf-herdr.fish"
  bin_dir=$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)
  export HERDR_BIN_PATH="$BATS_TEST_DIRNAME/fakes/herdr"
  export FAKE_HERDR_RECORD="$BATS_TEST_TMPDIR/herdr"
  mkdir "$FAKE_HERDR_RECORD"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export HERDR_ENV=1
  # fish creates its configuration, data, and cache directories when it starts.
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config" XDG_DATA_HOME="$BATS_TEST_TMPDIR/data" XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
  # fzf's own __fzfcmd can pick fzf-tmux.
  unset FZF_TMUX FZF_TMUX_OPTS FZF_CTRL_T_COMMAND FZF_CTRL_R_COMMAND FZF_ALT_C_COMMAND
}

# Runs the fish code in an interactive fish without configuration files, after loading fzf and fzf-herdr.
# The second argument runs between the two.
# Only the standard output is kept, since fzf's own functions report errors when fish has no command line.
run_fish() {
  run --separate-stderr fish --no-config -i -c "fzf --fish | source
${2-}
source '$fish_file'
$1"
}

@test "makes fzf-herdr callable by name" {
  run_fish 'command -s fzf-herdr'

  [ "$output" = "$bin_dir/fzf-herdr" ]
}

@test "keeps a linked location on PATH" {
  ln -s "$(cd "$BATS_TEST_DIRNAME/.." && pwd)" "$BATS_TEST_TMPDIR/linked"

  run fish --no-config -c "source '$BATS_TEST_TMPDIR/linked/shell/fzf-herdr.fish'; command -s fzf-herdr"

  [ "$output" = "$BATS_TEST_TMPDIR/linked/bin/fzf-herdr" ]
}

@test "keeps a linked location on PATH when loaded by a relative path" {
  ln -s "$(cd "$BATS_TEST_DIRNAME/.." && pwd)" "$BATS_TEST_TMPDIR/linked"
  cd "$BATS_TEST_TMPDIR/linked/shell"

  run fish --no-config -c 'source fzf-herdr.fish; command -s fzf-herdr'

  [ "$output" = "$BATS_TEST_TMPDIR/linked/bin/fzf-herdr" ]
}

@test "adds bin to PATH only once" {
  run_fish "source '$fish_file'; count (string match -- '$bin_dir' \$PATH)"

  [ "$output" = "1" ]
}

@test "points fzf's key bindings to fzf-herdr in herdr" {
  run_fish '__fzfcmd'

  [ "$output" = "fzf-herdr" ]
}

@test "opens the pane picked by each of fzf's keys" {
  local pair function
  # fzf filters its empty input in place of waiting for keys.
  export FZF_DEFAULT_OPTS=--filter=x
  for pair in '\cr:history' '\ct:files' '\ec:directories'; do
    # The binding of the default mode is the one without --preset and -M.
    function=$(fish --no-config -i -c "fzf --fish | source; bind ${pair%%:*}" 2> /dev/null |
      grep -v -e ' --preset ' -e ' -M ' | awk '{ print $NF }')
    [ -n "$function" ]
    run_fish "$function < /dev/null"
    herdr_received --entrypoint "${pair#*:}"
  done
}

@test "runs fzf's completion through fzf-herdr in herdr" {
  run_fish "printf '%s\n' apple banana | fzf_complete --filter ban"

  herdr_received --entrypoint completion
}

@test "picks the completion pane for fzf's completion before fzf 0.71" {
  run_fish 'fzf-completion' 'function __fzf_complete_native; __fzfcmd; end; function fzf-completion; __fzf_complete_native; end'

  [ "$output" = "env FZF_HERDR_ENTRYPOINT=completion fzf-herdr" ]
}

@test "runs fzf in place outside fzf's completion" {
  run_fish 'echo apple | fzf --filter app'

  [ "$output" = "apple" ]
  [ ! -e "$FAKE_HERDR_RECORD/args" ]
}

@test "keeps an fzf function defined before loading" {
  run_fish 'fzf' 'function fzf; echo user; end'

  [ "$output" = "user" ]
}

@test "leaves fzf's key bindings and completion alone outside herdr" {
  export HERDR_ENV=

  run_fish '__fzfcmd; type -t fzf'

  [ "${lines[0]}" = "fzf" ]
  [ "${lines[1]}" = "file" ]
}
