# usage: dotfiles uninstall [-n] [-l <layer>] [--keep-installed] [--no-push] <package>...
# Same as dotfiles remove.
cmd_uninstall() {
  . "$DOTFILES_CLI/commands/remove.sh"
  cmd_remove "$@"
}
