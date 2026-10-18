title="personal git identity in the dotfiles repo"
check() { [ -n "$(git -C "$DOTFILES_REPO" config --local user.email)" ]; }
fix() {
  ask ANS_personalEmail "Personal git email for personal repos (keeps a work address off public commits)" "thejase@gmail.com"
  git -C "$DOTFILES_REPO" config --local user.email "$ANS_personalEmail"
  git -C "$DOTFILES_REPO" config --local user.name "$(git config --global user.name 2>/dev/null || chezmoi execute-template '{{ .gitName }}')"
}
