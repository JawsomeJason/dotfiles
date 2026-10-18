# usage: dotfiles path [<layer>]
# Prints a layer's repo folder (the base by default), as in: cd "$(dotfiles path)"
cmd_path() {
  want=${1:-base}
  cfg=$(layers | awk -F'\t' -v want="$want" '$1 == want { print $2; found = 1 } END { exit !found }') ||
    die "no layer named '$want' (see dotfiles layers)"
  layer_root "$cfg" || die "$want: no git checkout behind its source"
}
