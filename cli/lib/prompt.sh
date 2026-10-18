# Prompts for the dotfiles CLI and its plugins. Sourced, never run.
#
# Questions are asked only in a terminal and only when no value arrived from a flag. Without a
# terminal, or with ASSUME_YES=1, every question takes its default, so agents and scripts run the
# same commands without prompts. gum draws the prompts when it is installed.

interactive() { [ -t 0 ] && [ -t 1 ] && [ "${ASSUME_YES:-0}" != 1 ]; }
has_gum() { command -v gum >/dev/null 2>&1; }

# ask VAR "Question" [default]: leaves VAR alone when it already holds a value
ask() {
  _var=$1 _q=$2 _def=${3:-}
  eval "_cur=\${$_var:-}"
  [ -n "$_cur" ] && return 0
  if ! interactive; then eval "$_var=\$_def"; return 0; fi
  if has_gum; then
    _ans=$(gum input --prompt "$_q: " --value "$_def" --width 0) || exit 130
  else
    if [ -n "$_def" ]; then printf '%s [%s]: ' "$_q" "$_def" >&2; else printf '%s: ' "$_q" >&2; fi
    IFS= read -r _ans || exit 130
    [ -n "$_ans" ] || _ans=$_def
  fi
  eval "$_var=\$_ans"
}

# confirm "Question" [y|n]: succeeds on yes; without a terminal it returns the default
confirm() {
  _q=$1 _def=${2:-y}
  if ! interactive; then [ "$_def" = y ]; return; fi
  if has_gum; then
    if [ "$_def" = y ]; then gum confirm "$_q"; else gum confirm --default=false "$_q"; fi
    return
  fi
  if [ "$_def" = y ]; then printf '%s [Y/n]: ' "$_q" >&2; else printf '%s [y/N]: ' "$_q" >&2; fi
  IFS= read -r _ans || exit 130
  case ${_ans:-$_def} in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# A value a step needs but no default can supply
require() {
  eval "_cur=\${$1:-}"
  [ -n "$_cur" ] || die "missing $2; pass $3 or run in a terminal"
}
