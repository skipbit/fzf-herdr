# fzf-herdr: shows fzf's key bindings and completion in a herdr popup.
# Source this file after fzf's own shell integration (e.g. `source <(fzf --zsh)`).

# Puts bin/ of this repository on PATH so that fzf-herdr can be called by name.
() {
  local bin=${${(%):-%x}:A:h:h}/bin
  (( ${path[(Ie)$bin]} )) || path=("$bin" $path)
}

[[ -n $HERDR_ENV ]] || return 0

# fzf's key bindings run the command that __fzfcmd prints.
__fzfcmd() {
  echo fzf-herdr
}

# fzf's completion runs _fzf_comprun when it is defined. A user's own definition is kept.
if (( ! $+functions[_fzf_comprun] )); then
  _fzf_comprun() {
    shift
    fzf-herdr "$@"
  }
fi
