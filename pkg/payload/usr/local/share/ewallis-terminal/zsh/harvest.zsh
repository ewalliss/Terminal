#!/usr/bin/env zsh
# harvest.zsh — auto-detect completion harvester for EwallisTerminal
#
# When you run a command that has no zsh completion loaded, this tries
# `<tool> completion zsh` (and common variants). If the tool emits a valid
# `#compdef` script, it's cached so future shells can complete/predict it —
# giving fish-style prediction for gh / docker / kubectl / etc. with no
# per-tool configuration.
#
# Design contract:
#   • the preexec hot path is FORK-FREE (tokenize + hash lookup + zstat + read)
#   • probing runs in a DETACHED worker (&!), never blocking the prompt
#   • freshness is keyed on the tool binary's mtime (upgrade → re-harvest)
#   • a newly harvested completion becomes active on the NEXT shell
#     (the daily compdump is invalidated so it rebuilds once)
#
# Sourced by: the managed zshrc block (registers the hook) and bin/ew-completions
# (reuses the probe/validate/write functions). Guarded by EWALLIS_NO_HARVEST.
# ─────────────────────────────────────────────────────────────────────────────

zmodload -F zsh/stat b:zstat 2>/dev/null

# Paths (respect an overridden HOME so the self-test sandbox stays contained).
_ew_harvest_cfg()  { print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}/ewallis-terminal"; }
_ew_harvest_comp() { print -r -- "$(_ew_harvest_cfg)/completions"; }
_ew_harvest_dir()  { print -r -- "$(_ew_harvest_cfg)/harvest"; }

# Tools that must never be probed with a `completion` subcommand: interactive
# programs, REPLs, network/DB clients, or anything that could block or misread
# the argument. A misparse or unsupported tool just lands in the negative cache.
typeset -ga _EW_HARVEST_DENY=(
  vi vim nvim nano emacs pico ed
  ssh scp sftp telnet ftp nc ncat netcat socat
  python python2 python3 ipython node deno bun irb ruby pry php lua
  mysql psql sqlite3 redis-cli mongo mongosh
  top htop less more man tmux screen
  sudo doas su login
)

_ew_harvest_denied() {
  local t=$1
  (( ${_EW_HARVEST_DENY[(Ie)$t]} )) && return 0
  return 1
}

# ── Base-command extraction ──────────────────────────────────────────────────
# Pull the real command word out of a command line, skipping env assignments
# and precommand wrappers. Imperfect cases (e.g. `sudo -u alice foo`) resolve
# to a wrong word that fails validation and is negative-cached once — harmless.
_ew_harvest_base() {
  local -a toks
  toks=(${(z)1})
  local w
  while (( $#toks )); do
    w=$toks[1]
    shift toks
    case $w in
      *=*)                                             continue ;;  # FOO=1 prefix
      sudo|doas|command|builtin|exec|nohup|nice|time|env|then|do|-*) continue ;;
      *) print -r -- $w; return 0 ;;
    esac
  done
  return 1
}

# ── The probe — hard 5s timeout without GNU timeout(1) (macOS lacks it) ──────
# perl's alarm timer survives exec, so exec-ing the tool keeps the watchdog.
_ew_harvest_probe() {
  local bin=$1; shift
  if (( $+commands[perl] )); then
    perl -e 'alarm(shift); exec @ARGV or exit 127' 5 "$bin" "$@" </dev/null 2>/dev/null
  else
    "$bin" "$@" </dev/null 2>/dev/null
  fi
}

# ── Validation — must be an autoloadable #compdef script, non-trivial, sane ──
_ew_harvest_valid() {
  local out=$1
  [[ -n $out ]] || return 1
  [[ ${out%%$'\n'*} == '#compdef'* ]] || return 1
  (( ${#out} >= 40 ))      || return 1
  (( ${#out} <= 1048576 )) || return 1
  return 0
}

# ── Atomic writers (also invalidate the daily compdump) ─────────────────────
_ew_harvest_write_ok() {   # $1 tool  $2 bin  $3 mtime  $4 script
  local cfg="$(_ew_harvest_cfg)" comp="$(_ew_harvest_comp)" h="$(_ew_harvest_dir)"
  mkdir -p "$comp" "$h/meta" "$h/neg" 2>/dev/null
  print -r -- "$4" > "$comp/_$1.$$" && mv -f "$comp/_$1.$$" "$comp/_$1"
  printf '%s\t%s\n' "$3" "$2" > "$h/meta/$1.$$" && mv -f "$h/meta/$1.$$" "$h/meta/$1"
  rm -f "$h/neg/$1"
  chmod 0644 "$comp/_$1" 2>/dev/null
  rm -f "$cfg/zcompdump" "$cfg/zcompdump.zwc"   # force one rebuild next shell
}

_ew_harvest_write_neg() {  # $1 tool  $2 bin  $3 mtime
  local comp="$(_ew_harvest_comp)" h="$(_ew_harvest_dir)"
  mkdir -p "$h/meta" "$h/neg" 2>/dev/null
  printf '%s\t%s\n' "$3" "$2" > "$h/neg/$1.$$" && mv -f "$h/neg/$1.$$" "$h/neg/$1"
  rm -f "$comp/_$1" "$h/meta/$1"                # clear a tool that lost support
}

# ── The worker — detached; claims a per-tool lock, probes, writes ───────────
_ew_harvest_run() {
  emulate -L zsh
  local tool=$1 bin=$2 mt=$3
  local h="$(_ew_harvest_dir)"
  mkdir -p "$h/lock" "$h/meta" "$h/neg" 2>/dev/null
  mkdir "$h/lock/$tool" 2>/dev/null || return   # another worker owns it
  {
    # Re-check under lock: another shell may have finished between spawn and now.
    local rec
    if [[ -e "$h/meta/$tool" ]]; then
      read -r rec _ < "$h/meta/$tool"
      [[ $rec == $mt ]] && return
    fi

    if _ew_harvest_denied "$tool"; then
      _ew_harvest_write_neg "$tool" "$bin" "$mt"
      return
    fi

    local out variant
    local -a variants=(
      'completion zsh'
      'completion --shell=zsh'
      'completion --shell zsh'
      '--completion-script-zsh'
      'completions zsh'
      'completion generate zsh'
    )
    for variant in $variants; do
      out=$(_ew_harvest_probe "$bin" ${(z)variant})
      if _ew_harvest_valid "$out"; then
        _ew_harvest_write_ok "$tool" "$bin" "$mt" "$out"
        return
      fi
    done
    _ew_harvest_write_neg "$tool" "$bin" "$mt"
  } always {
    rmdir "$h/lock/$tool" 2>/dev/null
  }
}

_ew_harvest_spawn() { { _ew_harvest_run "$@" } &! }

# ── The preexec hook — fork-free hot path ───────────────────────────────────
typeset -gA _EW_HARVEST_SEEN

_ew_harvest_maybe() {
  [[ -n ${EWALLIS_NO_HARVEST:-} ]] && return
  [[ -f "$(_ew_harvest_cfg)/harvest.disabled" ]] && return

  local tool
  tool=$(_ew_harvest_base "$1") || return
  [[ -n $tool && $tool != */* ]] || return

  local bin=${commands[$tool]}
  [[ -n $bin ]] || return                       # builtins/functions/aliases: skip

  local -a st
  zstat -A st +mtime -- "$bin" 2>/dev/null || return
  local mt=$st[1]

  [[ ${_EW_HARVEST_SEEN[$tool]:-} == $mt ]] && return   # already checked this shell

  local h="$(_ew_harvest_dir)" rec
  if [[ -e "$h/meta/$tool" ]]; then
    read -r rec _ < "$h/meta/$tool"
    [[ $rec == $mt ]] && { _EW_HARVEST_SEEN[$tool]=$mt; return; }   # fresh
  elif [[ -e "$h/neg/$tool" ]]; then
    read -r rec _ < "$h/neg/$tool"
    [[ $rec == $mt ]] && { _EW_HARVEST_SEEN[$tool]=$mt; return; }   # known-negative
  fi

  _EW_HARVEST_SEEN[$tool]=$mt                    # memo before dispatch: never double-spawn
  _ew_harvest_spawn "$tool" "$bin" "$mt"
}

# ── Foreground harvest for `ew completions add <tool>` ──────────────────────
# Returns 0 on success (valid completion written), 1 otherwise. Ignores cache.
_ew_harvest_force() {
  local tool=$1
  local bin=${commands[$tool]}
  [[ -n $bin ]] || { print -r -- "not an executable command: $tool" >&2; return 2; }
  local -a st
  zstat -A st +mtime -- "$bin" 2>/dev/null || { print -r -- "cannot stat $bin" >&2; return 2; }
  local mt=$st[1]

  if _ew_harvest_denied "$tool"; then
    _ew_harvest_write_neg "$tool" "$bin" "$mt"
    return 1
  fi

  local out variant
  local -a variants=(
    'completion zsh' 'completion --shell=zsh' 'completion --shell zsh'
    '--completion-script-zsh' 'completions zsh' 'completion generate zsh'
  )
  for variant in $variants; do
    out=$(_ew_harvest_probe "$bin" ${(z)variant})
    if _ew_harvest_valid "$out"; then
      _ew_harvest_write_ok "$tool" "$bin" "$mt" "$out"
      return 0
    fi
  done
  _ew_harvest_write_neg "$tool" "$bin" "$mt"
  return 1
}
