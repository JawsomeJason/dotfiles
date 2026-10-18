# Brewfile helpers shared by setup, install and remove. Sourced, never run.

# Every Brewfile this machine uses, one path per line: each layer's Brewfile, plus the base's
# Brewfile.personal on a personal machine
brewfiles() {
  layers | while IFS="$TAB" read -r name cfg; do
    root=$(layer_root "$cfg") || continue
    [ -f "$root/Brewfile" ] && echo "$root/Brewfile"
    if [ "$name" = base ] && [ -f "$root/Brewfile.personal" ] &&
      [ "$(layer_chezmoi "$cfg" execute-template '{{ .work }}' 2>/dev/null)" != true ]; then
      echo "$root/Brewfile.personal"
    fi
  done
}

# Whether a Brewfile lists a package, by full or short name
brewfile_lists() {
  grep -qE "^(brew|cask) \"([^\"]*/)?$2\"" "$1" 2>/dev/null
}
