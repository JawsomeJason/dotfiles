# usage: dotfiles apply [-n] [-l <layer>]
# Writes the base, then each layer, into the home folder. Stops first if two layers own one file.
cmd_apply() {
  check_collisions
  flags=
  [ "$DRY_RUN" = 1 ] && flags="--dry-run --verbose"
  selected_layers | while IFS="$TAB" read -r name cfg; do
    say "applying $name"
    # shellcheck disable=SC2086
    layer_chezmoi "$cfg" apply $flags "$@" || exit 1
  done
}
