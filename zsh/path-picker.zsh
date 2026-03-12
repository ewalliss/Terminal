#!/usr/bin/env zsh
# path-picker.zsh — Tab-triggered fzf path visualizer for zsh
# Triggers when cursor is on a path argument of a nav command or a bare path.
# Groups results: 󰉋 Folders · 󰈙 Files · 󰋇 Other (contains query)
# ─────────────────────────────────────────────────────────────────────────────

# ── Guard: fzf must be available ──────────────────────────────────────────────
(( ${+commands[fzf]} )) || return

# ── Constants (guarded so re-sourcing .zshrc doesn't error) ───────────────────
if (( ! ${+_PP_NAV_CMDS} )); then
  typeset -ra _PP_NAV_CMDS=(cd ls cat vim nvim nano less more cp mv rm open code)
  typeset -r  _PP_ICON_FOLDER='󰉋'
  typeset -r  _PP_ICON_FILE='󰈙'
  typeset -r  _PP_ICON_OTHER='󰋇'
  typeset -r  _PP_FZF_COLORS='bg+:#313244,fg+:#cdd6f4,hl+:#cba6f7,border:#45475a,label:#cba6f7,pointer:#cba6f7,header:italic:#6c7086'
fi

# ── 1. Context detection ──────────────────────────────────────────────────────
# Returns 0 (trigger) if: first word is a nav cmd, OR last word is a path,
# OR nav cmd followed by a space (about to type first arg).
_pp_is_path_context() {
  local words=("${(z)LBUFFER}")
  local first="${words[1]}"
  local last="${words[-1]}"

  (( ${_PP_NAV_CMDS[(Ie)$first]} )) && return 0
  [[ "$last" == /* || "$last" == ./* || "$last" == ~/* ]] && return 0
  [[ "${LBUFFER[-1]}" == ' ' ]] && (( ${_PP_NAV_CMDS[(Ie)$first]} )) && return 0

  return 1
}

# ── 2. Buffer parsing ─────────────────────────────────────────────────────────
# Sets in caller scope:
#   _pp_base_dir   — absolute path of directory to list
#   _pp_typed_dir  — the dir portion as the user typed it (for reinsertion)
#   _pp_query      — the last path component being typed (filter term)
#   _pp_prefix     — LBUFFER content before the path argument
_pp_parse_buffer() {
  local words=("${(z)LBUFFER}")
  local current="${words[-1]}"
  [[ "${LBUFFER[-1]}" == ' ' ]] && current=''

  if [[ "$current" == */* ]]; then
    local typed_dir="${current%/*}"
    _pp_query="${current##*/}"
    _pp_prefix="${LBUFFER%$current}"
    _pp_typed_dir="${typed_dir}/"

    # Resolve to absolute for directory listing
    local resolved="${typed_dir/#\~/$HOME}"
    [[ "$resolved" != /* ]] && resolved="$PWD/$resolved"
    _pp_base_dir="$resolved"
  else
    _pp_base_dir="$PWD"
    _pp_query="$current"
    _pp_prefix="${LBUFFER%$current}"
    _pp_typed_dir=""
  fi
}

# ── 3. List builder ───────────────────────────────────────────────────────────
# Outputs tab-delimited rows:  TYPE<TAB>NAME
#   TYPE: HEADER | D (dir) | F (file) | O (other)
# Section headers are TYPE=HEADER and are filtered out after selection.
_pp_build_list() {
  local base_dir="$1" query="$2"
  local -a dirs_match files_match other

  [[ -d "$base_dir" ]] || return 1

  local name
  while IFS= read -r name; do
    [[ "$name" == '.' || "$name" == '..' ]] && continue

    if [[ -d "$base_dir/$name" ]]; then
      name="${name}/"
      if [[ -z "$query" || "$name" == ${query}* ]]; then
        dirs_match+=("$name")
      elif [[ "$name" == *${query}* ]]; then
        other+=("$name")
      fi
    else
      if [[ -z "$query" || "$name" == ${query}* ]]; then
        files_match+=("$name")
      elif [[ "$name" == *${query}* ]]; then
        other+=("$name")
      fi
    fi
  done < <(ls -1a "$base_dir" 2>/dev/null)

  if (( ${#dirs_match} )); then
    printf "HEADER\t\033[1;35m${_PP_ICON_FOLDER}  Folders\033[0m\n"
    printf "D\t%s\n" "${dirs_match[@]}"
  fi

  if (( ${#files_match} )); then
    printf "HEADER\t\033[1;34m${_PP_ICON_FILE}  Files\033[0m\n"
    printf "F\t%s\n" "${files_match[@]}"
  fi

  if (( ${#other} )); then
    printf "HEADER\t\033[1;33m${_PP_ICON_OTHER}  Other\033[0m\n"
    printf "O\t%s\n" "${other[@]}"
  fi
}

# ── 4. ZLE widget ─────────────────────────────────────────────────────────────
_pp_widget() {
  _pp_is_path_context || return

  local _pp_base_dir _pp_typed_dir _pp_query _pp_prefix
  _pp_parse_buffer

  local list
  list=$(_pp_build_list "$_pp_base_dir" "$_pp_query")

  [[ -z "$list" ]] && return

  # Run fzf — read from /dev/tty so it works even with piped stdin
  local raw
  raw=$(
    printf '%s\n' "$list" | fzf \
      --ansi \
      --no-sort \
      --delimiter=$'\t' \
      --with-nth=2 \
      --nth=2 \
      --border=rounded \
      --border-label=" ${_PP_ICON_FOLDER} Path Picker " \
      --height=40% \
      --min-height=10 \
      --layout=reverse \
      --pointer='▶' \
      --color="$_PP_FZF_COLORS" \
      --prompt="  ${_pp_base_dir/$HOME/\~}/ " \
      --query="$_pp_query" \
      --bind='change:first' \
      --bind='/:accept' \
      < /dev/tty
  )

  zle reset-prompt

  # Parse result: TYPE<TAB>NAME
  local type="${raw%%$'\t'*}"
  local selected="${raw#*$'\t'}"

  # Esc / empty / header accidentally selected → no-op
  [[ -z "$raw" || "$type" == 'HEADER' ]] && return

  # Reconstruct LBUFFER with the selection
  LBUFFER="${_pp_prefix}${_pp_typed_dir}${selected}"
  zle reset-prompt

  # Directory selected → recurse to show its contents immediately
  [[ "$type" == 'D' ]] && _pp_widget
}

zle -N _pp_widget
bindkey '^F' _pp_widget   # Ctrl+F — open path picker
