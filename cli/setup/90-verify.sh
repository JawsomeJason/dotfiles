title="every layer applied"
check() { ! "$DOTFILES_CLI/dotfiles" status 2>/dev/null | grep -qv ': up to date$'; }
fix() { "$DOTFILES_CLI/dotfiles" apply; }
