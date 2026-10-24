# fzf-herdr

Open [fzf](https://github.com/junegunn/fzf) in a [herdr](https://herdr.dev) popup for shell key bindings and fuzzy completion.

fzf-herdr does for herdr what `fzf-tmux` does for tmux: it shows the fzf finder used by your shell's key bindings (CTRL-T, CTRL-R, ALT-C) and fuzzy completion (`**<TAB>`, or SHIFT-TAB in fish) in a herdr popup.

## Requirements

- herdr 0.9.3 or later
- fzf, with its shell integration (key bindings and completion) loaded
- zsh, bash, or fish 3.4 or later
- bash, to run the scripts (the one that ships with macOS works)
- macOS or Linux

Tested with zsh 5.9, bash 3.2, and fish 3.7 and 4.9 on macOS (herdr 0.9.5, fzf 0.74.4) and with zsh 5.9, bash 5.2, and fish 4.9 on Ubuntu 24.04 (herdr 0.9.5, fzf 0.56.0 and 0.74.2). Version 0.1.0 was also tested with herdr 0.9.3.

## Installation

Install the plugin with herdr:

```sh
herdr plugin install skipbit/fzf-herdr
```

The install runs `libexec/fzf-herdr-link`, which links the plugin to `~/.local/share/fzf-herdr` (`$XDG_DATA_HOME/fzf-herdr` if set).
On herdr 0.9.3, the install stops without the link, so install from a clone instead (see below).
Then load it in `~/.zshrc`, after fzf's own shell integration:

```zsh
source <(fzf --zsh)
source ~/.local/share/fzf-herdr/shell/fzf-herdr.zsh
```

For bash, load it in `~/.bashrc` in the same way:

```bash
eval "$(fzf --bash)"
source ~/.local/share/fzf-herdr/shell/fzf-herdr.bash
```

For fish, load it right after fzf's own line, in the same place.
That is `~/.config/fish/config.fish`:

```fish
fzf --fish | source
source ~/.local/share/fzf-herdr/shell/fzf-herdr.fish
```

If fzf's install script put its line in `fish_user_key_bindings`, load it there instead.
fish runs that function after `config.fish`, and loading fzf again there undoes fzf-herdr.

```fish
function fish_user_key_bindings
  fzf --fish | source
  source ~/.local/share/fzf-herdr/shell/fzf-herdr.fish
end
```

To update, run `herdr plugin update skipbit.fzf-herdr`. To recreate the link, run the install command again.
To uninstall, run `herdr plugin uninstall skipbit.fzf-herdr`, remove the line from your shell's configuration, and delete the link.

### From a clone

You can also clone this repository anywhere you like and register it with herdr.
Cloning it to `~/.local/share/fzf-herdr` keeps the lines above as they are.

```sh
git clone https://github.com/skipbit/fzf-herdr.git ~/.local/share/fzf-herdr
herdr plugin link ~/.local/share/fzf-herdr
```

To update, run `git -C ~/.local/share/fzf-herdr pull`.
To uninstall, run `herdr plugin unlink skipbit.fzf-herdr`, remove the line from your shell's configuration, and delete the directory.

## Usage

Inside herdr, CTRL-T, CTRL-R, ALT-C, and `**<TAB>` (SHIFT-TAB in fish) open fzf in a popup. Select and cancel as you do in plain fzf.
The popup is titled after what you are searching: `fzf: files` (CTRL-T), `fzf: history` (CTRL-R), `fzf: directories` (ALT-C), or `fzf: completion` (`**<TAB>` or SHIFT-TAB).
fzf's completion for fish (SHIFT-TAB) comes with fzf 0.68 or later.

`fzf-herdr` takes the same arguments as fzf, so you can also use it directly:

```sh
git branch | fzf-herdr --multi
```

This popup is titled `fzf`. To use one of the titles above, set `FZF_HERDR_ENTRYPOINT` to `files`, `history`, `directories`, or `completion`:

```sh
git ls-files | FZF_HERDR_ENTRYPOINT=files fzf-herdr --multi
```

Outside herdr, or while another popup is open, fzf-herdr runs fzf in place.
When the popup cannot be opened for another reason, such as the plugin being disabled or an unknown `FZF_HERDR_ENTRYPOINT`, it prints a one-line warning and runs fzf in place.

In the popup, herdr draws the frame, so fzf's `--height`, `--border`, and `--margin` are replaced with a narrow side margin.
The popup receives `FZF_DEFAULT_COMMAND`, `FZF_DEFAULT_OPTS`, `FZF_DEFAULT_OPTS_FILE`, `PATH`, `RUNEWIDTH_EASTASIAN`, and `BAT_THEME` from your shell; other environment variables come from the herdr server.

### Custom `_fzf_comprun`

If you define [`_fzf_comprun`](https://github.com/junegunn/fzf#customizing-fzf-options-for-completion) yourself, fzf-herdr keeps it.
Call `fzf-herdr` instead of `fzf` in it to use the popup, and set `FZF_HERDR_ENTRYPOINT=completion` to title it `fzf: completion`:

```sh
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd) FZF_HERDR_ENTRYPOINT=completion fzf-herdr --preview 'tree -C {} | head -200' "$@" ;;
    *)  FZF_HERDR_ENTRYPOINT=completion fzf-herdr --preview 'bat -n --color=always {}' "$@" ;;
  esac
}
```

### Your own `fzf` function in fish

From fzf 0.71, fzf's completion for fish runs `fzf` by name.
fzf-herdr defines an `fzf` function that opens the popup for the completion and runs fzf in place otherwise.
If you define `fzf` yourself (including with `alias`) before loading fzf-herdr, fzf-herdr keeps it, and the completion runs in place.
To keep the popup with options of your own, put them in `FZF_DEFAULT_OPTS` instead of an `fzf` function.

## Configuration

| Variable               | Description                                                                          | Default |
| ---------------------- | ------------------------------------------------------------------------------------ | ------- |
| `FZF_HERDR_WIDTH`      | Popup width, in cells or as a percentage (`80%`)                                     | `50%`   |
| `FZF_HERDR_HEIGHT`     | Popup height, in cells or as a percentage (`80%`)                                    | `50%`   |
| `FZF_HERDR_ENTRYPOINT` | Popup to open: `files`, `history`, `directories`, or `completion` for the titles above | `fzf`   |

## Development

Run the tests with [bats-core](https://github.com/bats-core/bats-core) and check the scripts with [shellcheck](https://www.shellcheck.net):

```sh
bats test/
shellcheck bin/fzf-herdr libexec/* test/fakes/* test/real-herdr-env .github/scripts/*.sh
shellcheck -s bash shell/*.bash test/*.bats test/helpers.bash
```

The zsh and fish tests are skipped when the shell is not installed.
The tests with a real herdr are skipped unless `FZF_HERDR_TEST_REAL_HERDR` is set.
They run herdr in a home of its own, apart from the one you use:

```sh
FZF_HERDR_TEST_REAL_HERDR=1 bats test/
```

Checks that need a person, such as key input in the popup, are listed in [test/manual.md](test/manual.md).

## License

[MIT](LICENSE)
