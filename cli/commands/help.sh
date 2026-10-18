# usage: dotfiles help [<command>]
# Lists commands, or shows one command's usage.
cmd_help() {
  if [ $# -gt 0 ]; then
    [ -f "$DOTFILES_CLI/commands/$1.sh" ] || die "no built-in command '$1'"
    command_help "$DOTFILES_CLI/commands/$1.sh"
    return
  fi
  cat <<USAGE
usage: dotfiles [options] [command] [args]

Applies the base dotfiles and every layer in ~/.config/chezmoi-layers/ with chezmoi.

commands:
USAGE
  for f in "$DOTFILES_CLI"/commands/*.sh; do
    name=$(basename "$f" .sh)
    printf '  %-10s %s\n' "$name" "$(command_help "$f" | sed -n 2p)"
  done
  plugins=$(IFS=:; for d in $PATH; do ls "$d"/dotfiles-* 2>/dev/null; done | xargs -n1 basename 2>/dev/null | sed 's/^dotfiles-//' | sort -u)
  if [ -n "$plugins" ]; then
    echo
    echo "plugins (dotfiles-<name> on PATH):"
    echo "$plugins" | sed 's/^/  /'
  fi
  cat <<USAGE

options:
  -h, --help          show this help
  -V, --version       print the base repo's version
  -n, --dry-run       preview apply or sync without writing
  -v, --verbose       print each chezmoi and git command
  -l, --layer <name>  act on one layer only
USAGE
}
