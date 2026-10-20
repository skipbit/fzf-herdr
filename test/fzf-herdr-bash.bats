#!/usr/bin/env bats
# Tests for shell/fzf-herdr.bash, loaded after fzf's own bash integration.

bats_require_minimum_version 1.5.0

load helpers

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  bash_file="$BATS_TEST_DIRNAME/../shell/fzf-herdr.bash"
  bin_dir=$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)
  export HERDR_BIN_PATH="$BATS_TEST_DIRNAME/fakes/herdr"
  export FAKE_HERDR_RECORD="$BATS_TEST_TMPDIR/herdr"
  mkdir "$FAKE_HERDR_RECORD"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export HERDR_ENV=1
  # An interactive bash reads and trims the history file.
  export HISTFILE="$BATS_TEST_TMPDIR/history"
  unset FZF_CTRL_T_COMMAND FZF_CTRL_R_COMMAND FZF_ALT_C_COMMAND
}

# Runs the bash code in an interactive bash without rc files, after loading fzf and fzf-herdr.
# Only the standard output is kept, since bash without a terminal reports that it has no job control.
run_bash() {
  run --separate-stderr bash --norc --noprofile -i -c "${2-}
eval \"\$(fzf --bash)\" 2> /dev/null
source '$bash_file'
$1"
}

# Prints the command that fzf binds to the key: a bind -x command (bash 4 and later),
# or the one in backquotes of a macro.
key_command() {
  local binding
  binding=$(bash --norc --noprofile -i -c 'eval "$(fzf --bash)"; bind -X; bind -s' 2> /dev/null | grep -F "\"$1\": ")
  binding=${binding#*': "'}
  binding=${binding%'"'}
  if [[ $binding == *'`'* ]]; then
    binding=${binding#*'`'}
    binding=${binding%%'`'*}
  fi
  echo "$binding"
}

@test "makes fzf-herdr callable by name" {
  run_bash 'type -P fzf-herdr'

  [ "$output" = "$bin_dir/fzf-herdr" ]
}

@test "keeps a linked location on PATH" {
  ln -s "$(cd "$BATS_TEST_DIRNAME/.." && pwd)" "$BATS_TEST_TMPDIR/linked"

  run bash --norc --noprofile -c "source '$BATS_TEST_TMPDIR/linked/shell/fzf-herdr.bash'; type -P fzf-herdr"

  [ "$output" = "$BATS_TEST_TMPDIR/linked/bin/fzf-herdr" ]
}

@test "adds bin to PATH only once" {
  run_bash "source '$bash_file'; tr : '\n' <<< \"\$PATH\" | grep -cxF '$bin_dir'"

  [ "$output" = "1" ]
}

@test "points fzf's key bindings to fzf-herdr in herdr" {
  run_bash '__fzfcmd'

  [ "$output" = "fzf-herdr" ]
}

@test "prints fzf-herdr outside the key bindings with nounset" {
  run_bash 'set -u; __fzfcmd'

  [ "$output" = "fzf-herdr" ]
}

@test "opens the pane picked by each of fzf's keys" {
  local pair command
  # fzf filters its empty input in place of waiting for keys.
  export FZF_DEFAULT_OPTS=--filter=x
  for pair in '\C-r:history' '\C-t:files' '\ec:directories'; do
    command=$(key_command "${pair%%:*}")
    [ -n "$command" ]
    run_bash "$command < /dev/null"
    herdr_received --entrypoint "${pair#*:}"
  done
}

@test "runs fzf's completion through fzf-herdr in herdr" {
  run_bash "printf '%s\n' apple banana | _fzf_comprun ls --filter ban"

  [ "$output" = "banana" ]
  herdr_received --entrypoint completion
}

@test "keeps a _fzf_comprun defined before loading" {
  run_bash '_fzf_comprun x' '_fzf_comprun() { echo user; }'

  [ "$output" = "user" ]
}

@test "leaves fzf's key bindings and completion alone outside herdr" {
  export HERDR_ENV=

  run_bash '__fzfcmd; declare -F _fzf_comprun || echo none'

  [ "${lines[0]}" = "fzf" ]
  [ "${lines[1]}" = "none" ]
}
