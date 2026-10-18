#USAGE cmd "edit" help="Open a layer's repo (the base by default) in your editor" {
#USAGE   arg "[layer]" help="Layer name" {
#USAGE     choices run="dotfiles layers --names"
#USAGE   }
#USAGE }
# Uses $VISUAL, then $EDITOR, then VS Code, then vi. Run dotfiles diff and dotfiles apply after editing.
cmd_edit() {
  root=$("$DOTFILES_CLI/dotfiles" path "${1:-base}") || exit 1
  editor=${VISUAL:-${EDITOR:-}}
  if [ -z "$editor" ]; then
    if command -v code >/dev/null 2>&1; then editor="code"; else editor="vi"; fi
  fi
  if [ "$DRY_RUN" = 1 ]; then say "would: $editor $root"; return; fi
  # shellcheck disable=SC2086
  exec $editor "$root"
}
