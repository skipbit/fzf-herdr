# Manual checks

These checks cover what needs a person: key input, how the herdr popup looks, and the shell's line editor.
Run them on macOS and Linux before a release and after changing the popup or the shell integration.

## Setup

1. Link the plugin: `herdr plugin link /path/to/fzf-herdr`
2. In a shell inside herdr, load fzf's integration first, then fzf-herdr:

   ```zsh
   source <(fzf --zsh)
   source /path/to/fzf-herdr/shell/fzf-herdr.zsh
   ```

   For bash, start it with `bash --norc` and load them in the same way:

   ```bash
   eval "$(fzf --bash)"
   source /path/to/fzf-herdr/shell/fzf-herdr.bash
   ```

   For fish, start it with an empty configuration directory (`XDG_CONFIG_HOME=$(mktemp -d) fish`) and load them in the same way.
   `fish --no-config` does not run `fish_user_key_bindings`, which one of the checks needs.

   ```fish
   fzf --fish | source
   source /path/to/fzf-herdr/shell/fzf-herdr.fish
   ```

## Install and update

Run these from a branch pushed to GitHub (`--ref BRANCH`).

- [ ] On herdr 0.9.4 or later, after `herdr plugin update skipbit.fzf-herdr` installs a new commit, CTRL-T still works in a shell opened before the update.
- [ ] On herdr 0.9.3, the install stops with a message to install from a clone.

## Key bindings and completion (zsh)

- [ ] CTRL-T opens fzf in a popup titled `fzf: files`, and the selected paths are inserted into the command line.
- [ ] CTRL-R opens the history in a popup titled `fzf: history`, and the selected command replaces the command line. A multi-line command is shown and inserted intact.
- [ ] ALT-C opens directories in a popup titled `fzf: directories`, and the shell changes to the selected directory.
- [ ] `vim **<TAB>` opens path completion in a popup titled `fzf: completion`, and `cd **<TAB>` opens directory completion in the same popup.
- [ ] Esc in the popup cancels each of the above and leaves the command line as it was.
- [ ] Colors and the preview window (e.g. `FZF_CTRL_T_OPTS="--preview 'cat {}'"`) look the same as in plain fzf.
- [ ] `FZF_HERDR_WIDTH=80% FZF_HERDR_HEIGHT=80%` changes the popup size.
- [ ] A `_fzf_comprun` defined before loading fzf-herdr is used for `**<TAB>` (in a popup when it calls `fzf-herdr`, titled `fzf: completion` when it sets `FZF_HERDR_ENTRYPOINT=completion`).
- [ ] `echo a | fzf-herdr` opens a popup titled `fzf`.

## Key bindings and completion (bash)

Check these with the bash that ships with macOS (3.2) and with bash 4 or later, since they bind the keys in different ways.

- [ ] CTRL-T opens fzf in a popup titled `fzf: files`, and the selected paths are inserted into the command line.
- [ ] CTRL-R opens the history in a popup titled `fzf: history`, and the selected command replaces the command line.
- [ ] ALT-C opens directories in a popup titled `fzf: directories`, and the shell changes to the selected directory.
- [ ] `vim **<TAB>` opens path completion in a popup titled `fzf: completion`, and `cd **<TAB>` opens directory completion in the same popup.
- [ ] Esc in the popup cancels each of the above and leaves the command line as it was.
- [ ] A `_fzf_comprun` defined before loading fzf-herdr is used for `**<TAB>`.
- [ ] In a bash started with `HERDR_ENV= bash --norc` and loaded as above, CTRL-T behaves as it does without fzf-herdr.

## Key bindings and completion (fish)

Check these with fish 3 and fish 4, since fzf's fish integration runs different code on them.

- [ ] CTRL-T opens fzf in a popup titled `fzf: files`, and the selected paths are inserted into the command line.
- [ ] CTRL-R opens the history in a popup titled `fzf: history`, and the selected command replaces the command line.
- [ ] ALT-C opens directories in a popup titled `fzf: directories`, and the shell changes to the selected directory.
- [ ] With fzf 0.68 or later, `vim ` and SHIFT-TAB open the completion in a popup titled `fzf: completion`, and the selected item is inserted into the command line.
- [ ] Esc in the popup cancels each of the above and leaves the command line as it was.
- [ ] `fzf` run from the command line opens in place.
- [ ] With an `fzf` function defined before loading fzf-herdr (e.g. `function fzf; command fzf $argv; end`), SHIFT-TAB runs fzf in place.
- [ ] With fzf and fzf-herdr loaded in `fish_user_key_bindings` as in the README, CTRL-T opens the popup, also after `set -g fish_key_bindings fish_vi_key_bindings`.
- [ ] In a fish started with `HERDR_ENV=` and loaded as above, CTRL-T behaves as it does without fzf-herdr.

## Fallback to fzf in place

- [ ] In a shell opened in a popup (a `type = "popup"` custom command), CTRL-T runs fzf in place without a warning.
- [ ] `sleep 3; echo a | fzf-herdr`, then open Settings or copy mode within 3 seconds: fzf opens without a warning (herdr 0.9.3 shows the popup on top of them), and Esc closes it.
- [ ] With the plugin disabled (`herdr plugin disable skipbit.fzf-herdr`), CTRL-T prints one warning and runs fzf in place. Enable it again afterwards.
- [ ] In a shell outside herdr, CTRL-T behaves as it does without fzf-herdr (including fzf-tmux inside tmux).
