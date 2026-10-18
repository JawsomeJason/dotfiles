title="Homebrew packages from every layer's Brewfile"
. "$DOTFILES_CLI/lib/brew.sh"
check() {
  for f in $(brewfiles); do brew bundle check --no-upgrade --file "$f" >/dev/null 2>&1 || return 1; done
}
fix() {
  for f in $(brewfiles); do
    brew bundle check --no-upgrade --file "$f" >/dev/null 2>&1 && continue
    echo "${f/#$HOME/~} is missing:"
    brew bundle check --no-upgrade --verbose --file "$f" 2>&1 | grep -E "needs to be" | sed 's/^→ /  /'
    confirm "Install them?" y || return 1
    brew bundle install --no-upgrade --file "$f"
  done
}
