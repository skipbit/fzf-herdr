# fzf-herdr: shows fzf's key bindings and completion in a herdr popup.
# Source this file after fzf's own shell integration (e.g. `source <(fzf --zsh)`).

# Puts bin/ of this repository on PATH so that fzf-herdr can be called by name.
# The path keeps links, so that a link updated by "herdr plugin update" also updates running shells.
() {
  local bin=${${(%):-%x}:a:h:h}/bin
  (( ${path[(Ie)$bin]} )) || path=("$bin" $path)
}

[[ -n $HERDR_ENV ]] || return 0

# fzf's key bindings run the command that __fzfcmd prints.
# The entrypoint, picked by the calling widget, sets the title of the popup.
__fzfcmd() {
  case $WIDGET in
    fzf-history-widget) echo fzf-herdr --fzf-herdr-entrypoint=history ;;
    fzf-file-widget) echo fzf-herdr --fzf-herdr-entrypoint=files ;;
    fzf-cd-widget) echo fzf-herdr --fzf-herdr-entrypoint=directories ;;
    *) echo fzf-herdr ;;
  esac
}

# fzf's completion runs _fzf_comprun when it is defined. A user's own definition is kept.
if (( ! $+functions[_fzf_comprun] )); then
  _fzf_comprun() {
    shift
    fzf-herdr --fzf-herdr-entrypoint=completion "$@"
  }
fi
