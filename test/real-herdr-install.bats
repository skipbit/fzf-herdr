#!/usr/bin/env bats
# Tests for "herdr plugin install" and "herdr plugin update" with a real herdr, run only when FZF_HERDR_TEST_REAL_HERDR is set.
# herdr has a home of its own, and fetches the plugin from a git repository of the test in place of GitHub.

bats_require_minimum_version 1.5.0

setup_file() {
  [[ -n ${FZF_HERDR_TEST_REAL_HERDR-} ]] || skip "set FZF_HERDR_TEST_REAL_HERDR to run the tests with a real herdr"
  command -v herdr > /dev/null || { echo "herdr is not installed" >&2; return 1; }
  export BATS_TEST_TIMEOUT=20
}

setup() {
  local home=$BATS_TEST_TMPDIR/home
  # No server listens on the socket, so herdr installs and updates the plugin by itself.
  local env=(
    env -i HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share"
    XDG_STATE_HOME="$home/.local/state" XDG_CACHE_HOME="$home/.cache"
    HERDR_CONFIG_PATH="$home/.config/herdr/config.toml" HERDR_SOCKET_PATH="$BATS_FILE_TMPDIR/herdr.sock"
    PATH="$PATH"
  )
  herdr=("${env[@]}" "$(command -v herdr)")
  git=("${env[@]}" git)
  repo=$BATS_TEST_TMPDIR/repo
  link=$home/.local/share/fzf-herdr

  mkdir -p "$home" "$repo"
  cat > "$home/.gitconfig" << EOF
[user]
name = fzf-herdr test
email = test@example.com
[url "file://$repo"]
insteadOf = https://github.com/skipbit/fzf-herdr.git
EOF
  # The repository holds the working tree as it is, committed or not.
  tar -C "$BATS_TEST_DIRNAME/.." --exclude=.git -cf - . | tar -C "$repo" -xf -
  "${git[@]}" -C "$repo" init -q
  "${git[@]}" -C "$repo" add -A
  "${git[@]}" -C "$repo" commit -qm test
}

# Prints the directory that herdr loads the plugin from.
plugin_root() {
  "${herdr[@]}" plugin list --json | grep -o '"plugin_root":"[^"]*"' | cut -d'"' -f4
}

# Succeeds when the link points to the plugin that herdr loads, at the commit of the repository.
links_installed_plugin() {
  local root
  root=$(plugin_root)
  [ -n "$root" ]
  [ "$(readlink "$link")" = "$(cd "$root" && pwd -P)" ]
  [ "$("${git[@]}" -C "$link" rev-parse HEAD)" = "$("${git[@]}" -C "$repo" rev-parse HEAD)" ]
  [ -f "$link/shell/fzf-herdr.zsh" ]
}

@test "links the installed plugin" {
  run "${herdr[@]}" plugin install --yes skipbit/fzf-herdr

  [ "$status" -eq 0 ]
  links_installed_plugin
}

@test "links the new checkout on update" {
  local old
  "${herdr[@]}" plugin install --yes skipbit/fzf-herdr
  old=$(readlink "$link")
  "${git[@]}" -C "$repo" commit -q --allow-empty -m update

  run "${herdr[@]}" plugin update --yes skipbit.fzf-herdr

  [ "$status" -eq 0 ]
  [ "$(readlink "$link")" != "$old" ]
  links_installed_plugin
}

@test "links the plugin again when installed again" {
  "${herdr[@]}" plugin install --yes skipbit/fzf-herdr
  rm "$link"

  run "${herdr[@]}" plugin install --yes skipbit/fzf-herdr

  [ "$status" -eq 0 ]
  links_installed_plugin
}

@test "stops the install and leaves a directory in place of the link alone" {
  mkdir -p "$link"

  run --separate-stderr "${herdr[@]}" plugin install --yes skipbit/fzf-herdr

  [ "$status" -eq 1 ]
  [ -d "$link" ]
  [ ! -L "$link" ]
  "${herdr[@]}" plugin list --json | grep -qF '"plugins":[]'
  [[ $stderr == *"fzf-herdr: $link is not a link; remove it, or keep using it with \"herdr plugin link\""* ]]
}
