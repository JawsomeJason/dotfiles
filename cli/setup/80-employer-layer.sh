title="employer layer (work machines only)"
check() {
  [ "$(chezmoi execute-template '{{ .work }}' 2>/dev/null)" = true ] || return 0
  for cfg in "$DOTFILES_LAYERS_DIR"/2[0-9]-*/chezmoi.toml; do [ -f "$cfg" ] && return 0; done
  return 1
}
fix() {
  job=$(command -v dotfiles-job 2>/dev/null || echo "$HOME/.local/bin/dotfiles-job")
  [ -x "$job" ] || die "dotfiles job is missing; the shared work layer provides it"
  confirm "Set up the employer layer now?" y || return 1
  "$job" new
}
