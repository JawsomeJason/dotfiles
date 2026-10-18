# Prints the full usage spec (hidden; used by help, the menu, docs and completion)
cmd__spec() {
  . "$DOTFILES_CLI/lib/spec.sh"
  spec
}
