# fzf-herdr

Open [fzf](https://github.com/junegunn/fzf) in a [Herdr](https://herdr.dev) popup for shell key bindings and fuzzy completion.

fzf-herdr does for Herdr what `fzf-tmux` does for tmux: it shows the fzf finder used by your shell's key bindings (CTRL-T, CTRL-R, ALT-C) and fuzzy completion (`**<TAB>`) in a Herdr popup.

## Requirements

- herdr 0.9.3 or later
- fzf, with its zsh integration (key bindings and completion) loaded
- zsh (bash and fish are not supported yet)
- bash, to run the scripts (the one that ships with macOS works)
- macOS or Linux

Tested with zsh 5.9 on macOS (herdr 0.9.3 and 0.9.5, fzf 0.74.4, bash 3.2) and Ubuntu 24.04 (herdr 0.9.3, fzf 0.56.0, bash 5.2).

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

To update, run `herdr plugin update skipbit.fzf-herdr`. To recreate the link, run the install command again.
To uninstall, run `herdr plugin uninstall skipbit.fzf-herdr`, remove the line from `~/.zshrc`, and delete the link.

### From a clone

You can also clone this repository anywhere you like and register it with herdr.
Cloning it to `~/.local/share/fzf-herdr` keeps the line in `~/.zshrc` above as it is.

```sh
git clone https://github.com/skipbit/fzf-herdr.git ~/.local/share/fzf-herdr
herdr plugin link ~/.local/share/fzf-herdr
```

To update, run `git -C ~/.local/share/fzf-herdr pull`.
To uninstall, run `herdr plugin unlink skipbit.fzf-herdr`, remove the line from `~/.zshrc`, and delete the directory.

## Usage

Inside Herdr, CTRL-T, CTRL-R, ALT-C, and `**<TAB>` open fzf in a popup. Select and cancel as you do in plain fzf.

`fzf-herdr` takes the same arguments as fzf, so you can also use it directly:

```sh
git branch | fzf-herdr --multi
```

Outside Herdr, or while another popup is open, fzf-herdr runs fzf in place.
When the popup cannot be opened for another reason, such as the plugin being disabled, it prints a one-line warning and runs fzf in place.

In the popup, Herdr draws the frame, so fzf's `--height`, `--border`, and `--margin` are replaced with a narrow side margin.
The popup receives `FZF_DEFAULT_COMMAND`, `FZF_DEFAULT_OPTS`, `FZF_DEFAULT_OPTS_FILE`, `PATH`, `RUNEWIDTH_EASTASIAN`, and `BAT_THEME` from your shell; other environment variables come from the Herdr server.

### Custom `_fzf_comprun`

If you define [`_fzf_comprun`](https://github.com/junegunn/fzf#customizing-fzf-options-for-completion) yourself, fzf-herdr keeps it.
Call `fzf-herdr` instead of `fzf` in it to use the popup:

```zsh
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd) fzf-herdr --preview 'tree -C {} | head -200' "$@" ;;
    *)  fzf-herdr --preview 'bat -n --color=always {}' "$@" ;;
  esac
}
```

## Configuration

| Variable           | Description                                      | Default |
| ------------------ | ------------------------------------------------ | ------- |
| `FZF_HERDR_WIDTH`  | Popup width, in cells or as a percentage (`80%`)  | `50%`   |
| `FZF_HERDR_HEIGHT` | Popup height, in cells or as a percentage (`80%`) | `50%`   |

## Development

Run the tests with [bats-core](https://github.com/bats-core/bats-core) and check the scripts with [ShellCheck](https://www.shellcheck.net):

```sh
bats test/
shellcheck bin/fzf-herdr libexec/* test/fakes/* .github/scripts/*.sh
shellcheck -s bash test/*.bats
```

Checks that need a real Herdr popup and key input are listed in [test/manual.md](test/manual.md).

## License

[MIT](LICENSE)
