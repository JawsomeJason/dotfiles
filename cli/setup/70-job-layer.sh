title="shared work layer (work machines only)"
is_work() { [ "$(chezmoi execute-template '{{ .work }}' 2>/dev/null)" = true ]; }
check() {
  is_work || return 0
  cfg=$DOTFILES_LAYERS_DIR/10-job/chezmoi.toml
  [ -f "$cfg" ] && [ -d "$(sed -n 's/^sourceDir = "\(.*\)"$/\1/p' "$cfg")" ]
}
fix() {
  ask ANS_jobRepo "Shared work layer repo (owner/name)" "JawsomeJason/dotjob"
  dir=$HOME/code/${ANS_jobRepo#*/}
  owner=${ANS_jobRepo%%/*}
  if [ ! -d "$dir/.git" ]; then
    GH_TOKEN=$(gh auth token -u "$owner" 2>/dev/null || gh auth token) gh repo clone "$ANS_jobRepo" "$dir"
  fi
  email=$(git -C "$DOTFILES_REPO" config --local user.email)
  [ -n "$email" ] && git -C "$dir" config --local user.email "$email"
  mkdir -p "$DOTFILES_LAYERS_DIR/10-job"
  printf 'sourceDir = "%s"\n' "$dir" > "$DOTFILES_LAYERS_DIR/10-job/chezmoi.toml"
  chezmoi --config "$DOTFILES_LAYERS_DIR/10-job/chezmoi.toml" apply
}
