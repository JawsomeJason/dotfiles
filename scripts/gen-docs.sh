#!/bin/sh
# Regenerates docs/cli.md and the zsh completion from the dotfiles usage spec.
#   scripts/gen-docs.sh          write them
#   scripts/gen-docs.sh --check  exit 1 when either is out of date (CI runs this)
# Needs usage (https://usage.jdx.dev). The docs cover the base commands only, so they read the same
# on every machine; completion asks `dotfiles __spec` at Tab time, so it includes plugins.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

DOTFILES_SPEC_BASE_ONLY=1 "$root/cli/dotfiles" __spec > "$out/dotfiles.usage.kdl"
usage lint "$out/dotfiles.usage.kdl" >/dev/null
usage generate markdown -f "$out/dotfiles.usage.kdl" --out-file "$out/cli.md" 2>/dev/null
usage generate completion zsh dotfiles --usage-cmd "dotfiles __spec" > "$out/_dotfiles"

check=0
[ "${1:-}" = --check ] && check=1
status=0
for pair in "cli.md:docs/cli.md" "_dotfiles:home/private_dot_config/zsh/completions/_dotfiles"; do
  src=$out/${pair%%:*} dest=$root/${pair#*:}
  if [ $check = 1 ]; then
    cmp -s "$src" "$dest" || { echo "out of date: ${pair#*:} (run scripts/gen-docs.sh)" >&2; status=1; }
  else
    mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"; echo "wrote ${pair#*:}"
  fi
done
exit $status
