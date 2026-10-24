#!/usr/bin/env bats
# Tests for fzf-herdr with a real herdr server, run only when FZF_HERDR_TEST_REAL_HERDR is set.
# The server has a home and a socket of its own and none of the variables of a herdr that runs the tests.

bats_require_minimum_version 1.5.0

setup_file() {
  [[ -n ${FZF_HERDR_TEST_REAL_HERDR-} ]] || skip "set FZF_HERDR_TEST_REAL_HERDR to run the tests with a real herdr"
  command -v herdr > /dev/null || { echo "herdr is not installed" >&2; return 1; }
  export BATS_TEST_TIMEOUT=20
  set_commands
  mkdir "$BATS_FILE_TMPDIR/home" "$BATS_FILE_TMPDIR/bin"

  # Records the process of fzf, the popup script that runs it, and the variables that herdr gives to the popup.
  cat > "$BATS_FILE_TMPDIR/bin/fzf" << EOF
#!/usr/bin/env bash
echo "\$\$ \$PPID \${TERM_PROGRAM:--} \${HERDR_PLUGIN_ENTRYPOINT_ID:--} \$(pwd -P)" >> "$BATS_FILE_TMPDIR/fzf-runs"
exec "$(command -v fzf)" "\$@"
EOF
  chmod +x "$BATS_FILE_TMPDIR/bin/fzf"

  "${herdr[@]}" server > "$BATS_FILE_TMPDIR/server.log" 2>&1 < /dev/null 3>&- &
  echo "$!" > "$BATS_FILE_TMPDIR/server.pid"
  wait_until test -S "$BATS_FILE_TMPDIR/herdr.sock"
  "${herdr[@]}" plugin link "$(cd "$BATS_TEST_DIRNAME/.." && pwd)" > /dev/null
  # A new server has no workspace, and a popup opens over the active one.
  "${herdr[@]}" workspace create --cwd "$BATS_FILE_TMPDIR" --focus > /dev/null
}

teardown_file() {
  local pid
  read -r pid 2> /dev/null < "$BATS_FILE_TMPDIR/server.pid" || return 0
  kill "$pid" 2> /dev/null
  wait_until gone "$pid"
}

setup() {
  set_commands
  fzf_herdr="$BATS_TEST_DIRNAME/../bin/fzf-herdr"
  printf '%s\n' apple banana cherry > "$BATS_TEST_TMPDIR/candidates"
  : > "$BATS_FILE_TMPDIR/fzf-runs"
  cd "$BATS_TEST_TMPDIR" || return
}

teardown() {
  local pid popup_pid
  # A test skipped by setup_file runs teardown without setup.
  [[ -e $BATS_FILE_TMPDIR/fzf-runs ]] || return 0
  for pid in $(jobs -p); do
    kill "$pid" 2> /dev/null
  done
  wait 2> /dev/null || true
  # herdr opens one popup at a time, so the popup of this test has to end before the next test.
  while read -r pid popup_pid _; do
    wait_until gone "$pid"
    wait_until gone "$popup_pid"
  done < "$BATS_FILE_TMPDIR/fzf-runs"
}

# Sets the commands that reach only the test server: herdr, and in_pane, which runs a command as in a pane of the server.
set_commands() {
  local home=$BATS_FILE_TMPDIR/home
  local env=(
    env -i HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share"
    XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache"
    HERDR_CONFIG_PATH="$home/.config/herdr/config.toml" HERDR_SOCKET_PATH="$BATS_FILE_TMPDIR/herdr.sock"
    TERM=xterm-256color
  )
  herdr=("${env[@]}" PATH="$PATH" "$(command -v herdr)")
  in_pane=("${env[@]}" HERDR_ENV=1 HERDR_BIN_PATH="$(command -v herdr)" TMPDIR="$BATS_FILE_TMPDIR" PATH="$BATS_FILE_TMPDIR/bin:$PATH")
}

# Waits up to 5 seconds until the command succeeds.
wait_until() {
  local i
  for ((i = 0; i < 50; i++)); do
    "$@" && return 0
    sleep 0.1
  done
  return 1
}

gone() {
  ! kill -0 "$1" 2> /dev/null
}

# Prints where fzf ran for each run: TERM_PROGRAM, the entrypoint, and the directory, with "-" for a missing variable.
fzf_runs() {
  cut -d' ' -f3- "$BATS_FILE_TMPDIR/fzf-runs"
}

# Starts fzf-herdr in the background with fzf waiting for keys in the popup, and waits until fzf runs.
start_waiting_popup() {
  "${in_pane[@]}" "$fzf_herdr" < /dev/null > /dev/null 2>&1 3>&- &
  caller_pid=$!
  wait_until test -s "$BATS_FILE_TMPDIR/fzf-runs"
  read -r fzf_pid popup_pid _ < "$BATS_FILE_TMPDIR/fzf-runs"
}

@test "returns the selection and the exit code of fzf in the popup" {
  run --separate-stderr "${in_pane[@]}" "$fzf_herdr" --filter ban < "$BATS_TEST_TMPDIR/candidates"

  [ "$status" -eq 0 ]
  [ "$output" = banana ]
  [ -z "$stderr" ]
  [ "$(fzf_runs)" = "herdr fzf $(pwd -P)" ]

  run "${in_pane[@]}" "$fzf_herdr" --filter missing < "$BATS_TEST_TMPDIR/candidates"
  [ "$status" -eq 1 ]
}

@test "opens each pane of the plugin" {
  local ids id expected=()
  ids=$(awk '/^\[\[panes\]\]$/ { panes = 1 } panes && /^id = / { gsub(/"/, "", $3); print $3 }' "$BATS_TEST_DIRNAME/../herdr-plugin.toml")
  [ -n "$ids" ]

  for id in $ids; do
    "${in_pane[@]}" FZF_HERDR_ENTRYPOINT="$id" "$fzf_herdr" --filter ban < "$BATS_TEST_TMPDIR/candidates" > /dev/null
    expected+=("herdr $id")
  done

  [ "$(fzf_runs | cut -d' ' -f1-2)" = "$(printf '%s\n' "${expected[@]}")" ]
}

@test "warns and runs fzf in place when the entrypoint is not found" {
  run --separate-stderr "${in_pane[@]}" FZF_HERDR_ENTRYPOINT=missing "$fzf_herdr" --filter ban < "$BATS_TEST_TMPDIR/candidates"

  [ "$status" -eq 0 ]
  [ "$output" = banana ]
  [ "$stderr" = "fzf-herdr: cannot open the herdr popup (plugin_pane_not_found); running fzf in place" ]
  [ "$(fzf_runs | cut -d' ' -f1-2)" = "- -" ]
}

@test "runs fzf in place without a warning while a popup is open" {
  start_waiting_popup

  run --separate-stderr "${in_pane[@]}" "$fzf_herdr" --filter ban < "$BATS_TEST_TMPDIR/candidates"

  [ "$status" -eq 0 ]
  [ "$output" = banana ]
  [ -z "$stderr" ]
  [ "$(fzf_runs | sed -n 2p | cut -d' ' -f1-2)" = "- -" ]
}

@test "closes the popup when fzf-herdr is stopped first" {
  local code=0
  start_waiting_popup

  kill -TERM "$caller_pid"
  wait "$caller_pid" || code=$?

  [ "$code" -eq 143 ]
  wait_until gone "$fzf_pid"
  wait_until gone "$popup_pid"
}

@test "gives its panes HERDR_ENV and HERDR_BIN_PATH" {
  local pane bin
  pane=$("${herdr[@]}" pane list | grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -n "$pane" ]

  "${herdr[@]}" pane run "$pane" "env > '$BATS_TEST_TMPDIR/env.tmp' && mv '$BATS_TEST_TMPDIR/env.tmp' '$BATS_TEST_TMPDIR/env'" > /dev/null
  wait_until test -e "$BATS_TEST_TMPDIR/env"

  grep -qx 'HERDR_ENV=1' "$BATS_TEST_TMPDIR/env"
  bin=$(sed -n 's/^HERDR_BIN_PATH=//p' "$BATS_TEST_TMPDIR/env")
  [ -x "$bin" ]
}
