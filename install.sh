#!/bin/bash
# Bootstraps a Mac: Homebrew, git, chezmoi, gh and gum, a clone of this repo in ~/code/dotfiles,
# then `dotfiles setup`, which asks the remaining questions. Safe to rerun.
#
#   curl -fsSL https://raw.githubusercontent.com/JawsomeJason/dotfiles/main/install.sh | bash
#
# Arguments pass through to `dotfiles setup`, for example: ... | bash -s -- --yes --work no
set -euo pipefail

repo=${DOTFILES_REPO_URL:-https://github.com/JawsomeJason/dotfiles.git}
dir=${DOTFILES_DIR:-$HOME/code/dotfiles}

if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Installing Homebrew (it asks for your password once)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

for tool in git chezmoi gh gum; do
  command -v "$tool" >/dev/null 2>&1 || brew install "$tool"
done

if [ ! -d "$dir/.git" ]; then
  mkdir -p "$(dirname "$dir")"
  git clone "$repo" "$dir"
fi

# When piped from curl, stdin is this script; give setup the terminal so it can ask questions
if [ -t 1 ] && [ -r /dev/tty ]; then
  exec "$dir/cli/dotfiles" setup "$@" </dev/tty
fi
exec "$dir/cli/dotfiles" setup "$@"
