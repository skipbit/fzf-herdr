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

@test "defines the panes that each shell integration opens, titled after them" {
  local file ids id
  for file in "$BATS_TEST_DIRNAME"/../shell/*; do
    ids=$(grep -o 'FZF_HERDR_ENTRYPOINT=[[:alnum:]:_-]*' "$file" | cut -d= -f2)
    [ -n "$ids" ]
    for id in $ids; do
      grep -A1 -x "id = \"$id\"" "$manifest" | grep -qx "title = \"fzf: $id\""
    done
  done
}
