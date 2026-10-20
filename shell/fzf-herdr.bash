# fzf-herdr: shows fzf's key bindings and completion in a herdr popup.
# Source this file after fzf's own shell integration (e.g. `eval "$(fzf --bash)"`).

# Puts bin/ of this repository on PATH so that fzf-herdr can be called by name.
# The path keeps links, so that a link updated by "herdr plugin update" also updates running shells.
if __fzf_herdr_bin=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../bin" && pwd); then
  [[ :$PATH: == *":$__fzf_herdr_bin:"* ]] || PATH=$__fzf_herdr_bin:$PATH
fi
unset __fzf_herdr_bin

[[ -n ${HERDR_ENV-} ]] || return 0

# fzf's key bindings run the command that __fzfcmd prints.
# The entrypoint, picked by the function of the key binding, sets the title of the popup.
__fzfcmd() {
  case ${FUNCNAME[1]-} in
    __fzf_history__) echo env FZF_HERDR_ENTRYPOINT=history fzf-herdr ;;
    __fzf_select__) echo env FZF_HERDR_ENTRYPOINT=files fzf-herdr ;;
    __fzf_cd__) echo env FZF_HERDR_ENTRYPOINT=directories fzf-herdr ;;
    *) echo fzf-herdr ;;
  esac
}

# fzf's completion runs _fzf_comprun when it is defined. A user's own definition is kept.
if ! declare -F _fzf_comprun > /dev/null; then
  _fzf_comprun() {
    shift
    FZF_HERDR_ENTRYPOINT=completion fzf-herdr "$@"
  }
fi
