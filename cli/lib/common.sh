# Shared helpers for the dotfiles CLI. Sourced, never run.
#
# A layer is one line of `layers`: name, a tab, then its chezmoi config file. The base comes first
# with an empty config (chezmoi's default config), then every
# $DOTFILES_LAYERS_DIR/NN-name/chezmoi.toml in name order. Every command walks this one list.

DOTFILES_LAYERS_DIR=${DOTFILES_LAYERS_DIR:-$HOME/.config/chezmoi-layers}
DOTFILES_BASE_CONFIG=${DOTFILES_BASE_CONFIG:-}
TAB=$(printf '\t')

die() { echo "dotfiles: $*" >&2; exit 1; }
say() { echo "$*"; }
note() { [ "$VERBOSE" = 1 ] && echo "+ $*" >&2; return 0; }

layers() {
  printf 'base\t%s\n' "$DOTFILES_BASE_CONFIG"
  for cfg in "$DOTFILES_LAYERS_DIR"/*/chezmoi.toml; do
    [ -f "$cfg" ] || continue
    dir=$(basename "$(dirname "$cfg")")
    printf '%s\t%s\n' "${dir#[0-9][0-9]-}" "$cfg"
  done
}

# Layers to act on: all of them, or only the one named by -l/--layer
selected_layers() {
  if [ -z "$ONLY_LAYER" ]; then layers; return; fi
  layers | awk -F'\t' -v want="$ONLY_LAYER" '$1 == want { print; found = 1 } END { exit !found }' ||
    die "no layer named '$ONLY_LAYER' (see dotfiles layers)"
}

# chezmoi for one layer: layer_chezmoi <config> <args...>
layer_chezmoi() {
  cfg=$1; shift
  command -v chezmoi >/dev/null 2>&1 || die "chezmoi is not installed (brew install chezmoi)"
  if [ -n "$cfg" ]; then
    note chezmoi --config "$cfg" "$@"
    chezmoi --config "$cfg" "$@"
  else
    note chezmoi "$@"
    chezmoi "$@"
  fi
}

# The git checkout a layer's source lives in
layer_root() {
  src=$(layer_chezmoi "$1" source-path 2>/dev/null) || return 1
  git -C "$src" rev-parse --show-toplevel 2>/dev/null
}

# Stops when two layers manage the same file, since each apply would overwrite the other
check_collisions() {
  dupes=$(layers | while IFS="$TAB" read -r name cfg; do
    owned=$(layer_chezmoi "$cfg" managed --include files,symlinks --path-style absolute) ||
      die "$name: chezmoi could not list its files; fix that layer before applying"
    [ -n "$owned" ] && echo "$owned" | sed "s|^|$name$TAB|"
  done | sort -t "$TAB" -k2 | awk -F'\t' '
    $2 == prev { if (!shown[$2]++) print "  " $2 " (" prevname ", " $1 ")"; else print "  " $2 " (" $1 ")" }
    { prev = $2; prevname = $1 }') || exit 1
  [ -z "$dupes" ] && return 0
  echo "dotfiles: these files are managed by more than one layer; each must have exactly one owner:" >&2
  echo "$dupes" >&2
  exit 1
}

# The leading comment block of a command file: line 1 is its usage, line 2 its one-line summary
command_help() {
  awk '/^#/ { sub(/^# ?/, ""); print; next } { exit }' "$1"
}
