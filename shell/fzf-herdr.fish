# fzf-herdr: shows fzf's key bindings and completion in a herdr popup.
# Source this file right after fzf's own shell integration (`fzf --fish | source`), in the same place.

# Puts bin/ of this repository on PATH so that fzf-herdr can be called by name.
# The path keeps links, so that a link updated by "herdr plugin update" also updates running shells.
# realpath -s keeps links only in an absolute path.
set -l file (status current-filename)
string match -q -- '/*' $file; or set file $PWD/$file
set -l bin (builtin realpath -s -- $file/../../bin)
contains -- $bin $PATH; or set -gx PATH $bin $PATH

# return would leave a function that sources this file, such as fish_user_key_bindings.
if test -n "$HERDR_ENV"
  # Prints the functions that called the caller of this function, nearest first.
  # The stack trace is read in English, since fish translates it.
  function __fzf_herdr_callers
    set -lx LANGUAGE en
    set -l stack (status stack-trace | string match -r -g "^in function '([^']*)'")
    string join \n -- $stack[3..-1]
  end

  # fzf's key bindings, and its completion before fzf 0.71, run the command that __fzfcmd prints.
  # The entrypoint, picked by the calling functions, sets the title of the popup.
  function __fzfcmd
    set -l callers (__fzf_herdr_callers)
    if contains -- fzf_complete $callers; or contains -- fzf-completion $callers
      echo env FZF_HERDR_ENTRYPOINT=completion fzf-herdr
      return
    end
    switch "$callers[1]"
      case fzf-history-widget
        echo env FZF_HERDR_ENTRYPOINT=history fzf-herdr
      case fzf-file-widget
        echo env FZF_HERDR_ENTRYPOINT=files fzf-herdr
      case fzf-cd-widget
        echo env FZF_HERDR_ENTRYPOINT=directories fzf-herdr
      case '*'
        echo fzf-herdr
    end
  end

  # fzf's completion from fzf 0.71 runs fzf by name, which runs this function. A user's own fzf function is kept.
  if not functions -q fzf
    function fzf
      set -l callers (__fzf_herdr_callers)
      if contains -- fzf_complete $callers; or contains -- fzf-completion $callers
        FZF_HERDR_ENTRYPOINT=completion fzf-herdr $argv
      else
        command fzf $argv
      end
    end
  end
end
