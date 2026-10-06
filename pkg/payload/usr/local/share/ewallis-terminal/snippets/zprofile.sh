# >>> ewallis-terminal >>>
# Homebrew on PATH — a fresh macOS account has no `brew shellenv` line, so
# starship/fzf would look missing even though they are installed. Read-only:
# this never writes to the Homebrew prefix, whoever owns it.
if ! command -v brew >/dev/null 2>&1; then
  for _ewallis_brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$_ewallis_brew" ]]; then
      eval "$("$_ewallis_brew" shellenv)"
      break
    fi
  done
  unset _ewallis_brew
fi
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
# <<< ewallis-terminal <<<
