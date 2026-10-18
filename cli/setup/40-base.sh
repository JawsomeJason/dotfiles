title="base dotfiles applied to the home folder"
check() { [ -z "$(chezmoi status 2>/dev/null)" ] && [ -L "$HOME/.local/bin/dotfiles" ]; }
fix() {
  chezmoi diff --no-pager | head -200
  confirm "Apply these changes to the home folder?" y || return 1
  chezmoi apply
}
