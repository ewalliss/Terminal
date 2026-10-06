#!/usr/bin/env zsh
# path-picker.zsh — Ctrl+F fzf path visualizer for zsh
#
# Explicit-trigger only: bound to Ctrl+F. Deliberately does NOT wrap the
# self-insert widget — auto-opening the picker on every space after a nav
# command proved too disruptive (fired on every argument of cd/ls/cp/...).
# ─────────────────────────────────────────────────────────────────────────────

(( ${+commands[fzf]} )) || return

if (( ! ${+_PP_NAV_CMDS} )); then
  typeset -ra _PP_NAV_CMDS=(cd ls cat vim nvim nano less more cp mv rm open code)
  typeset -r  _PP_ICON_FOLDER=''
  typeset -r  _PP_ICON_FILE=''
  typeset -r  _PP_ICON_OTHER=''
  typeset -r  _PP_FZF_COLORS='bg+:#313244,fg+:#cdd6f4,hl+:#cba6f7,border:#45475a,label:#cba6f7,pointer:#cba6f7,header:italic:#6c7086'

  # Per-file-type icons — opt-in via `ew icons catppuccin` (default: the 3
  # generic glyphs above, unchanged). Read once per shell, like the other
  # ewallis-terminal feature flags.
  if [[ -f "$HOME/.config/ewallis-terminal/icons.catppuccin" ]]; then
    typeset -gi _PP_ICONS_ON=1
  else
    typeset -gi _PP_ICONS_ON=0
  fi

  if (( _PP_ICONS_ON )); then
    # Codepoints from the Nerd Fonts glyph reference (nf-dev-*/nf-seti-*/etc,
    # via \uXXXX so the exact glyph is unambiguous regardless of editor/font).
    typeset -grA _PP_EXT_ICON=(
      sh   $''  zsh  $''  bash $''
      py   $''
      js   $''  mjs  $''  cjs  $''
      ts   $''  tsx  $''
      json $''
      yml  $''  yaml $''
      toml $''  ini  $''  cfg  $''
      lock $''
      gitignore $''  gitattributes $''
      md   $''  markdown $''
      png  $''  jpg $''  jpeg $''  gif $''  svg $''  ico $''  webp $''
      pdf  $''
      zip  $''  tar $''  gz $''  tgz $''  bz2 $''  xz $''
      html $''  htm $''
      css  $''  scss $''  sass $''
      rb   $''
      go   $''
      rs   $''
      c    $''  h $''
    )
    typeset -grA _PP_EXT_COLOR=(
      sh a6e3a1   zsh a6e3a1  bash a6e3a1
      py f9e2af
      js f9e2af   mjs f9e2af  cjs f9e2af
      ts 89b4fa   tsx 89b4fa
      json fab387
      yml f38ba8  yaml f38ba8
      toml 94e2d5 ini 94e2d5  cfg 94e2d5
      lock eba0ac
      gitignore fab387  gitattributes fab387
      md 74c7ec   markdown 74c7ec
      png f5c2e7  jpg f5c2e7  jpeg f5c2e7 gif f5c2e7  svg f5c2e7  ico f5c2e7  webp f5c2e7
      pdf f38ba8
      zip fab387  tar fab387  gz fab387  tgz fab387  bz2 fab387  xz fab387
      html fab387 htm fab387
      css b4befe  scss b4befe sass b4befe
      rb f38ba8
      go 89dceb
      rs eba0ac
      c 89b4fa    h 89b4fa
    )
  fi
fi

# ── 0. Icon rendering (catppuccin style only — no-ops, unchanged text, when off)
_pp_ansi_fg() {
  local hex="$1" r g b
  (( ${#hex} == 6 )) || return
  (( r = 16#${hex[1,2]}, g = 16#${hex[3,4]}, b = 16#${hex[5,6]} ))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

_pp_dir_display() {
  local name="$1"
  (( _PP_ICONS_ON )) || { printf '%s' "$name"; return }
  printf '%s%s\033[0m  %s' "$(_pp_ansi_fg cba6f7)" "$_PP_ICON_FOLDER" "$name"
}

_pp_file_display() {
  local name="$1"
  (( _PP_ICONS_ON )) || { printf '%s' "$name"; return }
  [[ "$name" == */ ]] && { _pp_dir_display "$name"; return }
  local ext="${${name:e}:l}"
  local glyph="${_PP_EXT_ICON[$ext]:-$_PP_ICON_FILE}"
  local hex="${_PP_EXT_COLOR[$ext]:-89b4fa}"
  printf '%s%s\033[0m  %s' "$(_pp_ansi_fg "$hex")" "$glyph" "$name"
}

# Emits one fzf group: a HEADER row plus one row per entry. In default mode
# (icons off) this produces byte-identical output to the pre-icons format.
_pp_emit_group() {
  local type_char="$1" icon="$2" ansi_n="$3" label="$4"; shift 4
  local hdr; hdr=$(printf '\033[1;%sm%s  %s\033[0m' "$ansi_n" "$icon" "$label")
  if (( _PP_ICONS_ON )); then
    printf 'HEADER\t%s\t%s\n' "$hdr" "$hdr"
    local e
    for e in "$@"; do
      printf "${type_char}\t%s\t%s\n" "$e" "$(_pp_file_display "$e")"
    done
  else
    printf 'HEADER\t%s\n' "$hdr"
    printf "${type_char}\t%s\n" "$@"
  fi
}

# ── 1. Context detection ──────────────────────────────────────────────────────
# Empty buffer counts as path context so a bare Ctrl+F browses $PWD.
_pp_is_path_context() {
  [[ -z "$LBUFFER" ]] && return 0
  local words=("${(z)LBUFFER}")
  local first="${words[1]}" last="${words[-1]}"
  (( ${_PP_NAV_CMDS[(Ie)$first]} )) && return 0
  [[ "$last" == /* || "$last" == ./* || "$last" == ~/* ]] && return 0
  return 1
}

# ── 2. Buffer parsing ─────────────────────────────────────────────────────────
_pp_parse_buffer() {
  local words=("${(z)LBUFFER}")
  local current="${words[-1]}"
  [[ -z "$LBUFFER" || "${LBUFFER[-1]}" == ' ' ]] && current=''

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
# Fills the caller's _pp_dirs / _pp_files / _pp_other arrays via zsh dynamic
# scoping (namerefs need zsh > 5.9, which macOS doesn't ship).
_pp_collect() {
  local base_dir="$1" query="$2"

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
    if   [[ -z "$query" || "$n" == ${query}* ]]; then _pp_dirs+=("$n")
    elif [[ "$n" == *${query}* ]];                then _pp_other+=("$n")
    fi
  done

  for name in $raw_files; do
    if   [[ -z "$query" || "$name" == ${query}* ]]; then _pp_files+=("$name")
    elif [[ "$name" == *${query}* ]];                then _pp_other+=("$name")
    fi
  done
}

# ── 4. ZLE widget ─────────────────────────────────────────────────────────────
_pp_widget() {
  _pp_is_path_context || return

  local _pp_base_dir _pp_typed_dir _pp_query _pp_prefix
  _pp_parse_buffer

  local -a _pp_dirs _pp_files _pp_other
  _pp_collect "$_pp_base_dir" "$_pp_query"

  (( ${#_pp_dirs} + ${#_pp_files} + ${#_pp_other} )) || return

  # Inhibit ZLE redisplay while fzf owns the terminal — prevents artifacts
  zle -I

  local -a _pp_fzf_opts=(
    --ansi --no-sort --delimiter=$'\t'
    --border=rounded --border-label=" ${_PP_ICON_FOLDER} Path Picker "
    --height=40% --min-height=8 --layout=reverse --pointer='▶'
    --color="$_PP_FZF_COLORS" --prompt="  ${_pp_base_dir/$HOME/\~}/ "
    --query="$_pp_query" --bind='change:first'
  )
  # NOTE: --nth indexes fields of the line AFTER --with-nth transforms it, not
  # the original tab-split fields — with a single field left post-transform,
  # the only valid index is 1. (Using 2 here — the pre-icons value — matched
  # nothing as soon as a query was typed, since field 2 no longer exists.)
  if (( _PP_ICONS_ON )); then
    _pp_fzf_opts+=(--with-nth=3 --nth=1)
  else
    _pp_fzf_opts+=(--with-nth=2 --nth=1)
  fi

  local raw
  raw=$(
    {
      (( ${#_pp_dirs}  )) && _pp_emit_group D "$_PP_ICON_FOLDER" 35 Folders "${_pp_dirs[@]}"
      (( ${#_pp_files} )) && _pp_emit_group F "$_PP_ICON_FILE"   34 Files   "${_pp_files[@]}"
      (( ${#_pp_other} )) && _pp_emit_group O "$_PP_ICON_OTHER"  33 Other   "${_pp_other[@]}"
    } | fzf "${_pp_fzf_opts[@]}"
  )

  zle reset-prompt

  local type="${raw%%$'\t'*}"
  local selected="${raw#*$'\t'}"
  (( _PP_ICONS_ON )) && selected="${selected%%$'\t'*}"

  [[ -z "$raw" || "$type" == 'HEADER' ]] && return

  LBUFFER="${_pp_prefix}${_pp_typed_dir}${selected}"
  zle reset-prompt

  [[ "$type" == 'D' ]] && _pp_widget
}

zle -N _pp_widget
bindkey '^F' _pp_widget
