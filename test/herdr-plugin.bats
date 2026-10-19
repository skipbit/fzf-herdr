#!/usr/bin/env bats
# Tests for herdr-plugin.toml.

setup() {
  manifest="$BATS_TEST_DIRNAME/../herdr-plugin.toml"
}

# Prints the settings of each pane on one line, leaving out its id and title.
pane_settings() {
  awk '
    /^\[/ { if (panes) print settings; panes = ($0 == "[[panes]]"); settings = ""; next }
    panes && NF && !/^(id|title) = / { settings = settings $0 " " }
    END { if (panes) print settings }
  ' "$manifest"
}

@test "sets every pane the same, besides its id and title" {
  run pane_settings

  [ "${#lines[@]}" -eq "$(grep -cx '\[\[panes\]\]' "$manifest")" ]
  [ "$(sort -u <<< "$output" | wc -l)" -eq 1 ]
}
