#USAGE cmd "path" help="Print a layer's repo folder (the base by default), as in: cd \"$(dotfiles path)\"" {
#USAGE   arg "[layer]" help="Layer name" {
#USAGE     choices run="dotfiles layers --names"
#USAGE   }
#USAGE }
cmd_path() {
  want=${1:-base}
  cfg=$(layers | awk -F'\t' -v want="$want" '$1 == want { print $2; found = 1 } END { exit !found }') ||
    die "no layer named '$want' (see dotfiles layers)"
  layer_root "$cfg" || die "$want: no git checkout behind its source"
}
