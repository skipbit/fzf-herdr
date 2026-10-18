# Manual checks

These checks cover what `bats test/` cannot: the real herdr popup, key input, and the shell's line editor.
Run them on macOS and Linux before a release and after changing the popup or the shell integration.

## Setup

1. Link the plugin: `herdr plugin link /path/to/fzf-herdr`
2. In a shell inside herdr, load fzf's integration first, then fzf-herdr:

   ```zsh
   source <(fzf --zsh)
   source /path/to/fzf-herdr/shell/fzf-herdr.zsh
   ```

## Key bindings and completion (zsh)

- [ ] CTRL-T opens fzf in a popup titled `fzf`, and the selected paths are inserted into the command line.
- [ ] CTRL-R opens the history in the popup, and the selected command replaces the command line. A multi-line command is shown and inserted intact.
- [ ] ALT-C opens directories in the popup, and the shell changes to the selected directory.
- [ ] `vim **<TAB>` opens path completion in the popup, and `cd **<TAB>` opens directory completion.
- [ ] Esc in the popup cancels each of the above and leaves the command line as it was.
- [ ] Colors and the preview window (e.g. `FZF_CTRL_T_OPTS="--preview 'cat {}'"`) look the same as in plain fzf.
- [ ] `FZF_HERDR_WIDTH=80% FZF_HERDR_HEIGHT=80%` changes the popup size.
- [ ] A `_fzf_comprun` defined before loading fzf-herdr is used for `**<TAB>` (in a popup when it calls `fzf-herdr`).

## Fallback to fzf in place

- [ ] In a shell opened in a popup (a `type = "popup"` custom command), CTRL-T runs fzf in place without a warning.
- [ ] `sleep 3; echo a | fzf-herdr`, then open Settings or copy mode within 3 seconds: fzf opens without a warning (herdr 0.9.3 shows the popup on top of them), and Esc closes it.
- [ ] With the plugin disabled (`herdr plugin disable skipbit.fzf-herdr`), CTRL-T prints one warning and runs fzf in place. Enable it again afterwards.
- [ ] In a shell outside herdr, CTRL-T behaves as it does without fzf-herdr (including fzf-tmux inside tmux).
