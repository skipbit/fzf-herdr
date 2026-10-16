#!/usr/bin/env bats
# Tests for bin/fzf-herdr, with the fake herdr running the popup script in place of a real popup.
# shellcheck disable=SC2030,SC2031 # each test runs in its own subshell

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  fzf_herdr="$BATS_TEST_DIRNAME/../bin/fzf-herdr"
  export HERDR_BIN_PATH="$BATS_TEST_DIRNAME/fakes/herdr"
  export FAKE_HERDR_RECORD="$BATS_TEST_TMPDIR/herdr"
  mkdir "$FAKE_HERDR_RECORD"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export HERDR_ENV=1
  unset FAKE_HERDR_ERROR FZF_DEFAULT_COMMAND FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE
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

wait_for_file() {
  local i
  for ((i = 0; i < 30; i++)); do
    [ -e "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

# Starts fzf-herdr in the background with a slow fzf and waits until the popup script is running.
start_with_slow_fzf() {
  use_fake_fzf
  export FAKE_FZF_SLEEP=5
  printf 'candidate\n' | "$fzf_herdr" > /dev/null 3>&- &
  caller_pid=$!
  wait_for_file "$FAKE_HERDR_RECORD/args"
  session_dir=$(tr '\0' '\n' < "$FAKE_HERDR_RECORD/args" | sed -n 's/^_FZF_HERDR_DIR=//p')
  wait_for_file "$session_dir/popup_pid"
  read -r popup_pid < "$session_dir/popup_pid"
}

# Runs fzf-herdr on piped candidates and keeps its output and error output.
run_filter() {
  out=$(printf '%s\n' apple banana | "$fzf_herdr" --filter ban 2> "$BATS_TEST_TMPDIR/stderr")
  err=$(cat "$BATS_TEST_TMPDIR/stderr")
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

@test "runs fzf in place outside herdr" {
  export HERDR_ENV=

  run_filter

  [ "$out" = "banana" ]
  [ -z "$err" ]
  [ ! -e "$FAKE_HERDR_RECORD/args" ]
}

@test "runs fzf in place without a warning while herdr is busy" {
  export FAKE_HERDR_ERROR=ui_busy

  run_filter

  [ "$out" = "banana" ]
  [ -z "$err" ]
}

@test "warns and runs fzf in place when the popup cannot be opened" {
  export FAKE_HERDR_ERROR=plugin_not_found

  run_filter

  [ "$out" = "banana" ]
  [ "$err" = "fzf-herdr: cannot open the herdr popup (plugin_not_found); running fzf in place" ]
}

@test "warns and runs fzf in place when herdr cannot be run" {
  export HERDR_BIN_PATH="$BATS_TEST_TMPDIR/missing"

  run_filter

  [ "$out" = "banana" ]
  [[ $err == "fzf-herdr: cannot open the herdr popup ("*"); running fzf in place" ]]
}

@test "ends with 130 when the popup closes without reporting" {
  start_with_slow_fzf

  kill -HUP -- "-$popup_pid"
  rc=0
  wait "$caller_pid" || rc=$?

  [ "$rc" -eq 130 ]
  [ ! -e "$session_dir" ]
}

@test "closes the popup when it is stopped first" {
  start_with_slow_fzf

  start=$SECONDS
  kill -TERM "$caller_pid"
  rc=0
  wait "$caller_pid" || rc=$?
  sleep 0.3

  [ "$rc" -eq 143 ]
  [ $((SECONDS - start)) -lt 3 ]
  run kill -0 -- "-$popup_pid"
  [ "$status" -ne 0 ]
  [ ! -e "$session_dir" ]
}
