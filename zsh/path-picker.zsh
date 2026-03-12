#!/usr/bin/env zsh
# path-picker.zsh — Ctrl+F fzf path visualizer for zsh
# ─────────────────────────────────────────────────────────────────────────────

(( ${+commands[fzf]} )) || return

if (( ! ${+_PP_NAV_CMDS} )); then
  typeset -ra _PP_NAV_CMDS=(cd ls cat vim nvim nano less more cp mv rm open code)
  typeset -r  _PP_ICON_FOLDER='󰉋'
  typeset -r  _PP_ICON_FILE='󰈙'
  typeset -r  _PP_ICON_OTHER='󰋇'
  typeset -r  _PP_FZF_COLORS='bg+:#313244,fg+:#cdd6f4,hl+:#cba6f7,border:#45475a,label:#cba6f7,pointer:#cba6f7,header:italic:#6c7086'
fi

# ── 1. Context detection ──────────────────────────────────────────────────────
_pp_is_path_context() {
  local words=("${(z)LBUFFER}")
  local first="${words[1]}" last="${words[-1]}"
  (( ${_PP_NAV_CMDS[(Ie)$first]} )) && return 0
  [[ "$last" == /* || "$last" == ./* || "$last" == ~/* ]] && return 0
  [[ "${LBUFFER[-1]}" == ' ' ]] && (( ${_PP_NAV_CMDS[(Ie)$first]} )) && return 0
  return 1
}

# ── 2. Buffer parsing ─────────────────────────────────────────────────────────
_pp_parse_buffer() {
  local words=("${(z)LBUFFER}")
  local current="${words[-1]}"
  [[ "${LBUFFER[-1]}" == ' ' ]] && current=''

  if [[ "$current" == */* ]]; then
    local typed_dir="${current%/*}"
    _pp_query="${current##*/}"
    _pp_prefix="${LBUFFER%$current}"
    _pp_typed_dir="${typed_dir}/"
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

# ── 3. Entry collection — zsh globs only, no subprocess, no ls ────────────────
# Fills caller arrays via namerefs: _pp_collect base_dir query dirs files other
_pp_collect() {
  local base_dir="$1" query="$2"
  local -n _c_dirs=$3 _c_files=$4 _c_other=$5

  [[ -d "$base_dir" ]] || return 1

  # ND/ = dirs incl. dotfiles, null glob (no error if empty)
  # ND^/ = non-dirs incl. dotfiles, null glob
  local -a raw_dirs raw_files
  raw_dirs=($base_dir/*(ND/))
  raw_files=($base_dir/*(ND^/))

  # Strip base_dir/ prefix → bare names
  local pfx="${base_dir}/"
  raw_dirs=("${raw_dirs[@]#$pfx}")
  raw_files=("${raw_files[@]#$pfx}")

  local name
  for name in $raw_dirs; do
    local n="${name}/"
    if   [[ -z "$query" || "$n" == ${query}* ]]; then _c_dirs+=("$n")
    elif [[ "$n" == *${query}* ]];                then _c_other+=("$n")
    fi
  done

  for name in $raw_files; do
    if   [[ -z "$query" || "$name" == ${query}* ]]; then _c_files+=("$name")
    elif [[ "$name" == *${query}* ]];                then _c_other+=("$name")
    fi
  done
}

# ── 4. ZLE widget ─────────────────────────────────────────────────────────────
_pp_widget() {
  _pp_is_path_context || return

  local _pp_base_dir _pp_typed_dir _pp_query _pp_prefix
  _pp_parse_buffer

  local -a dirs files other
  _pp_collect "$_pp_base_dir" "$_pp_query" dirs files other

  (( ${#dirs} + ${#files} + ${#other} )) || return

  # Inhibit ZLE redisplay while fzf owns the terminal — prevents artifacts
  zle -I

  local raw
  raw=$(
    {
      (( ${#dirs}  )) && { printf "HEADER\t\033[1;35m%s  Folders\033[0m\n" "$_PP_ICON_FOLDER"; printf "D\t%s\n" "${dirs[@]}";  }
      (( ${#files} )) && { printf "HEADER\t\033[1;34m%s  Files\033[0m\n"   "$_PP_ICON_FILE";   printf "F\t%s\n" "${files[@]}"; }
      (( ${#other} )) && { printf "HEADER\t\033[1;33m%s  Other\033[0m\n"   "$_PP_ICON_OTHER";  printf "O\t%s\n" "${other[@]}"; }
    } | fzf \
        --ansi \
        --no-sort \
        --delimiter=$'\t' \
        --with-nth=2 \
        --nth=2 \
        --border=rounded \
        --border-label=" ${_PP_ICON_FOLDER} Path Picker " \
        --height=40% \
        --min-height=8 \
        --layout=reverse \
        --pointer='▶' \
        --color="$_PP_FZF_COLORS" \
        --prompt="  ${_pp_base_dir/$HOME/\~}/ " \
        --query="$_pp_query" \
        --bind='change:first'
  )

  zle reset-prompt

  local type="${raw%%$'\t'*}"
  local selected="${raw#*$'\t'}"

  [[ -z "$raw" || "$type" == 'HEADER' ]] && return

  LBUFFER="${_pp_prefix}${_pp_typed_dir}${selected}"
  zle reset-prompt

  [[ "$type" == 'D' ]] && _pp_widget
}

# ── 5. Auto-trigger on space after a nav command ─────────────────────────────
# Wraps self-insert: after typing a space in a nav command context, open picker
# immediately. Ctrl+F stays as a manual fallback for mid-word use.
_pp_auto_trigger() {
  zle .self-insert
  [[ "$KEYS" == ' ' ]] && _pp_is_path_context && _pp_widget
}

zle -N _pp_widget
zle -N self-insert _pp_auto_trigger
bindkey '^F' _pp_widget   # Ctrl+F — manual fallback
