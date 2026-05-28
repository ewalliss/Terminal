# >>> ewallis-terminal >>>
# Managed block — do not edit between these markers.
# Remove with: /usr/local/share/ewallis-terminal/bin/ewallis-terminal-uninstall
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
_catppuccin_esc_clear_line() { BUFFER=""; CURSOR=0; }
zle -N _catppuccin_esc_clear_line
bindkey '\e\e' _catppuccin_esc_clear_line
# <<< ewallis-terminal <<<
