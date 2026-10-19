#!/usr/bin/env bats
# Tests for shell/fzf-herdr.zsh, loaded after fzf's own zsh integration.

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  command -v zsh > /dev/null || skip "zsh is not installed"
  zsh_file="$BATS_TEST_DIRNAME/../shell/fzf-herdr.zsh"
  bin_dir=$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)
  export HERDR_BIN_PATH="$BATS_TEST_DIRNAME/fakes/herdr"
  export FAKE_HERDR_RECORD="$BATS_TEST_TMPDIR/herdr"
  mkdir "$FAKE_HERDR_RECORD"
  export TMPDIR="$BATS_TEST_TMPDIR"
  export HERDR_ENV=1
}

# Runs the zsh code in an interactive zsh without rc files, after loading fzf and fzf-herdr.
run_zsh() {
  run zsh -fi -c "${2-}
source <(fzf --zsh) 2> /dev/null
source '$zsh_file'
$1"
}

@test "makes fzf-herdr callable by name" {
  run_zsh 'whence -p fzf-herdr'

  [ "$output" = "$bin_dir/fzf-herdr" ]
}

@test "keeps a linked location on PATH" {
  ln -s "$(cd "$BATS_TEST_DIRNAME/.." && pwd)" "$BATS_TEST_TMPDIR/linked"

  run zsh -f -c "source '$BATS_TEST_TMPDIR/linked/shell/fzf-herdr.zsh'; whence -p fzf-herdr"

  [ "$output" = "$BATS_TEST_TMPDIR/linked/bin/fzf-herdr" ]
}

@test "adds bin to PATH only once" {
  run_zsh "source '$zsh_file'; m=(\${(M)path:#$bin_dir}); print \${#m}"

  [ "$output" = "1" ]
}

@test "points fzf's key bindings to fzf-herdr in herdr" {
  run_zsh '__fzfcmd'

  [ "$output" = "fzf-herdr" ]
}

@test "prints fzf-herdr outside widgets with nounset" {
  run_zsh 'setopt nounset; __fzfcmd'

  [ "$output" = "fzf-herdr" ]
}

@test "opens the pane picked by the widget of fzf's key binding" {
  local pair
  for pair in fzf-history-widget:history fzf-file-widget:files fzf-cd-widget:directories; do
    # fzf's key bindings run the output of __fzfcmd unquoted, as this does.
    run_zsh "WIDGET=${pair%%:*}; \$(__fzfcmd) --filter x < /dev/null"
    [ "$(tr '\0' '\n' < "$FAKE_HERDR_RECORD/args" | grep -A1 -x -- --entrypoint | tail -1)" = "${pair#*:}" ]
  done
}

@test "knows the widgets that fzf binds to its keys" {
  run_zsh 'bindkey "^T"; bindkey "^R"; bindkey "\ec"' 'unset FZF_CTRL_T_COMMAND FZF_ALT_C_COMMAND'

  [ "${lines[0]}" = '"^T" fzf-file-widget' ]
  [ "${lines[1]}" = '"^R" fzf-history-widget' ]
  [ "${lines[2]}" = '"^[c" fzf-cd-widget' ]
}

@test "runs fzf's completion through fzf-herdr in herdr" {
  run_zsh "printf '%s\n' apple banana | _fzf_comprun ls --filter ban"

  [ "$output" = "banana" ]
  [ "$(tr '\0' '\n' < "$FAKE_HERDR_RECORD/args" | grep -A1 -x -- --entrypoint | tail -1)" = "completion" ]
}

@test "uses only entrypoints that the manifest defines, titled after them" {
  ids=$(grep -o 'FZF_HERDR_ENTRYPOINT=[a-z]*' "$zsh_file" | cut -d= -f2)

  [ "$(wc -l <<< "$ids")" -eq 4 ]
  for id in $ids; do
    grep -A1 -x "id = \"$id\"" "$BATS_TEST_DIRNAME/../herdr-plugin.toml" | grep -qx "title = \"fzf: $id\""
  done
}

@test "keeps a _fzf_comprun defined before loading" {
  run_zsh '_fzf_comprun x' '_fzf_comprun() { echo user; }'

  [ "$output" = "user" ]
}

@test "leaves fzf's key bindings and completion alone outside herdr" {
  export HERDR_ENV=

  run_zsh '__fzfcmd; whence -w _fzf_comprun'

  [ "${lines[0]}" = "fzf" ]
  [ "${lines[1]}" = "_fzf_comprun: none" ]
}
