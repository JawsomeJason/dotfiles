#USAGE cmd "version" help="Print the base repo's version, from its latest tag"
cmd_version() {
  git -C "$DOTFILES_CLI/.." describe --tags --always --dirty 2>/dev/null || echo unknown
}
