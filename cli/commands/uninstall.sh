# Alias of remove; its spec lives in remove.sh.
cmd_uninstall() {
  . "$DOTFILES_CLI/commands/remove.sh"
  cmd_remove "$@"
}
