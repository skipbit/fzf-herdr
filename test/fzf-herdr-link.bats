#!/usr/bin/env bats
# Tests for libexec/fzf-herdr-link.

setup_file() {
  export BATS_TEST_TIMEOUT=10
}

setup() {
  link_script="$BATS_TEST_DIRNAME/../libexec/fzf-herdr-link"
  root=$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir "$HOME"
  unset XDG_DATA_HOME
}

@test "links the checkout under XDG_DATA_HOME" {
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"

  run "$link_script"

  [ "$status" -eq 0 ]
  [ "$(readlink "$XDG_DATA_HOME/fzf-herdr")" = "$root" ]
}

@test "links the checkout under ~/.local/share without XDG_DATA_HOME" {
  run "$link_script"

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.local/share/fzf-herdr")" = "$root" ]
}

@test "replaces an existing link" {
  mkdir -p "$HOME/.local/share" "$BATS_TEST_TMPDIR/old"
  ln -s "$BATS_TEST_TMPDIR/old" "$HOME/.local/share/fzf-herdr"

  run "$link_script"

  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.local/share/fzf-herdr")" = "$root" ]
  [ -d "$BATS_TEST_TMPDIR/old" ]
}

@test "does not link a checkout in the temporary directory of herdr 0.9.3" {
  checkout="$BATS_TEST_TMPDIR/plugins/.tmp-install-1-2/checkout"
  mkdir -p "$checkout/libexec"
  cp "$link_script" "$checkout/libexec/"

  run "$checkout/libexec/fzf-herdr-link"

  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.local/share/fzf-herdr" ]
  [[ $output == *"install it from a clone"* ]]
}

@test "leaves a directory in place of the link alone" {
  mkdir -p "$HOME/.local/share/fzf-herdr"
  touch "$HOME/.local/share/fzf-herdr/clone"

  run "$link_script"

  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.local/share/fzf-herdr" ]
  [ -e "$HOME/.local/share/fzf-herdr/clone" ]
  [[ $output == *"is not a link"* ]]
}
