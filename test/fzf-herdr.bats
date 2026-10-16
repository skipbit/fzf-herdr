#!/usr/bin/env bats
# Tests for bin/fzf-herdr, with the fake herdr running the popup script in place of a real popup.

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  fzf_herdr="$BATS_TEST_DIRNAME/../bin/fzf-herdr"
  export HERDR_BIN_PATH="$BATS_TEST_DIRNAME/fakes/herdr"
  export FAKE_HERDR_RECORD="$BATS_TEST_TMPDIR/herdr"
  mkdir "$FAKE_HERDR_RECORD"
  export TMPDIR="$BATS_TEST_TMPDIR"
  unset FZF_DEFAULT_COMMAND FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE
  unset RUNEWIDTH_EASTASIAN BAT_THEME FZF_HERDR_WIDTH FZF_HERDR_HEIGHT
}

teardown() {
  local pids
  pids=$(jobs -p)
  # shellcheck disable=SC2086
  [ -z "$pids" ] || { kill $pids && wait; } 2> /dev/null || true
}

use_fake_fzf() {
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_FZF_RECORD="$BATS_TEST_TMPDIR/fzf"
  mkdir "$FAKE_FZF_RECORD"
}

# Succeeds when the fake herdr received the option followed by a value matching the pattern.
herdr_received() {
  local args=() arg i
  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < "$FAKE_HERDR_RECORD/args"
  for ((i = 0; i + 1 < ${#args[@]}; i++)); do
    # shellcheck disable=SC2053
    [[ ${args[i]} == "$1" && ${args[i + 1]} == $2 ]] && return 0
  done
  return 1
}

@test "returns the selection and the exit code of fzf" {
  use_fake_fzf
  export FAKE_FZF_OUTPUT='picked' FAKE_FZF_EXIT=130

  run "$fzf_herdr" < /dev/null

  [ "$status" -eq 130 ]
  [ "$output" = "picked" ]
}

@test "feeds piped candidates to fzf" {
  out=$(printf '%s\n' apple banana 'big banana' | "$fzf_herdr" --filter ban)

  [ "$out" = $'banana\nbig banana' ]
}

@test "passes the options to fzf unchanged" {
  use_fake_fzf
  options=(--query 'a b' $'line1\nline2' '' "it's \"quoted\"")

  "$fzf_herdr" "${options[@]}" < /dev/null

  cmp <(printf '%s\0' "${options[@]}" --no-height --border=none --margin=0,1 --bind=ctrl-z:ignore) "$FAKE_FZF_RECORD/args"
}

@test "opens the fzf pane of the plugin in the current directory" {
  use_fake_fzf
  cd "$BATS_TEST_TMPDIR"

  "$fzf_herdr" < /dev/null

  herdr_received --plugin skipbit.fzf-herdr
  herdr_received --entrypoint fzf
  herdr_received --cwd "$BATS_TEST_TMPDIR"
}

@test "passes the fzf variables and PATH even when empty" {
  use_fake_fzf
  export FZF_DEFAULT_OPTS=$'--height 40%\n--multi' FZF_DEFAULT_OPTS_FILE=''

  "$fzf_herdr" < /dev/null

  herdr_received --env $'FZF_DEFAULT_OPTS=--height 40%\n--multi'
  herdr_received --env 'FZF_DEFAULT_OPTS_FILE='
  herdr_received --env 'FZF_DEFAULT_COMMAND='
  herdr_received --env "PATH=$PATH"
}

@test "passes RUNEWIDTH_EASTASIAN and BAT_THEME only when set" {
  use_fake_fzf

  "$fzf_herdr" < /dev/null
  run herdr_received --env 'RUNEWIDTH_EASTASIAN=*'
  [ "$status" -eq 1 ]
  run herdr_received --env 'BAT_THEME=*'
  [ "$status" -eq 1 ]

  RUNEWIDTH_EASTASIAN=1 BAT_THEME=Dracula "$fzf_herdr" < /dev/null
  herdr_received --env 'RUNEWIDTH_EASTASIAN=1'
  herdr_received --env 'BAT_THEME=Dracula'
}

@test "passes the popup size only when set" {
  use_fake_fzf

  "$fzf_herdr" < /dev/null
  run herdr_received --width '*'
  [ "$status" -eq 1 ]
  run herdr_received --height '*'
  [ "$status" -eq 1 ]

  FZF_HERDR_WIDTH=80% FZF_HERDR_HEIGHT=30 "$fzf_herdr" < /dev/null
  herdr_received --width 80%
  herdr_received --height 30
}

@test "removes the temporary directory" {
  use_fake_fzf

  "$fzf_herdr" < /dev/null

  herdr_received --env '_FZF_HERDR_DIR=*'
  [ -z "$(find "$BATS_TEST_TMPDIR" -maxdepth 1 -name 'fzf-herdr-*')" ]
}
