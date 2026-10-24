#!/usr/bin/env bats
# Tests for libexec/fzf-herdr-popup.

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  popup="$BATS_TEST_DIRNAME/../libexec/fzf-herdr-popup"
  dir="$BATS_TEST_TMPDIR/session"
  mkdir "$dir"
  mkfifo "$dir/out" "$dir/code"
  : > "$dir/args"
  export _FZF_HERDR_DIR="$dir"
  start_caller
}

teardown() {
  local pid
  # bats runs its timeout as a job of the test and stops it itself.
  for pid in $(jobs -p); do
    if [[ $pid != "${BATS_killer_pid-}" ]]; then
      kill "$pid" 2> /dev/null
      wait "$pid" 2> /dev/null || true
    fi
  done
}

# Stands in for fzf-herdr and records SIGUSR1 as the "notified" file.
start_caller() {
  (
    trap 'touch "$BATS_TEST_TMPDIR/notified"; exit 0' USR1
    while :; do
      sleep 0.1 3>&- &
      wait $!
    done
  ) 3>&- &
  export _FZF_HERDR_CALLER_PID=$!
}

# Gives the stand-in caller time to handle a signal that may have been sent.
settle() {
  sleep 0.3
}

use_fake_fzf() {
  export PATH="$BATS_TEST_DIRNAME/fakes:$PATH"
  export FAKE_FZF_RECORD="$BATS_TEST_TMPDIR/record"
  mkdir "$FAKE_FZF_RECORD"
}

# Runs the popup script with the given standard input and collects what it reports.
run_popup() {
  "$popup" < "${1:-/dev/null}" 3>&- &
  out=$(cat "$dir/out")
  code=$(cat "$dir/code")
  wait $!
}

@test "passes the options unchanged and appends the popup options" {
  use_fake_fzf
  options=(--query 'a b' $'line1\nline2' '' "it's \"quoted\"")
  printf '%s\0' "${options[@]}" > "$dir/args"

  run_popup

  cmp <(printf '%s\0' "${options[@]}" --no-height --border=none --margin=0,1 --bind=ctrl-z:ignore) "$FAKE_FZF_RECORD/args"
}

@test "feeds the candidates from the in pipe" {
  use_fake_fzf
  mkfifo "$dir/in"
  printf 'from in\n' > "$dir/in" 3>&- &
  printf 'inherited\n' > "$BATS_TEST_TMPDIR/stdin"

  run_popup "$BATS_TEST_TMPDIR/stdin"

  [ "$(cat "$FAKE_FZF_RECORD/stdin")" = "from in" ]
}

@test "leaves the standard input to fzf without the in pipe" {
  use_fake_fzf
  printf 'inherited\n' > "$BATS_TEST_TMPDIR/stdin"

  run_popup "$BATS_TEST_TMPDIR/stdin"

  [ "$(cat "$FAKE_FZF_RECORD/stdin")" = "inherited" ]
}

@test "reports the output and the exit code of fzf without notifying the caller" {
  use_fake_fzf
  export FAKE_FZF_OUTPUT='picked' FAKE_FZF_EXIT=130

  run_popup

  [ "$out" = "picked" ]
  [ "$code" = "130" ]
  settle
  [ ! -e "$BATS_TEST_TMPDIR/notified" ]
}

@test "notifies the caller when it ends before reporting the exit code" {
  use_fake_fzf
  export FAKE_FZF_SLEEP=1
  "$popup" < /dev/null 3>&- &
  popup_pid=$!
  cat "$dir/out" > /dev/null 3>&- &
  sleep 0.3

  kill -HUP "$popup_pid"
  rc=0
  wait "$popup_pid" || rc=$?

  [ "$rc" -eq 129 ]
  settle
  [ -e "$BATS_TEST_TMPDIR/notified" ]
}

@test "works with the real fzf" {
  mkfifo "$dir/in"
  printf '%s\0' --filter ban > "$dir/args"
  printf '%s\n' apple banana 'big banana' > "$dir/in" 3>&- &

  run_popup

  [ "$out" = $'banana\nbig banana' ]
  [ "$code" = "0" ]
}
