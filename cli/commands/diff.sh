# usage: dotfiles diff [-l <layer>]
# Shows the exact changes apply would make, layer by layer.
cmd_diff() {
  selected_layers | while IFS="$TAB" read -r name cfg; do
    out=$(layer_chezmoi "$cfg" diff --no-pager "$@") || die "$name: chezmoi diff failed"
    [ -n "$out" ] && { say "### $name"; echo "$out"; }
  done
}
