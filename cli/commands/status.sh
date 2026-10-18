# usage: dotfiles [status] [-l <layer>]
# Shows what apply would change, layer by layer (the default command).
cmd_status() {
  selected_layers | while IFS="$TAB" read -r name cfg; do
    out=$(layer_chezmoi "$cfg" status 2>&1) || { echo "$out" >&2; die "$name: chezmoi status failed"; }
    if [ -z "$out" ]; then say "$name: up to date"; else say "$name:"; echo "$out" | sed 's/^/  /'; fi
  done
}
