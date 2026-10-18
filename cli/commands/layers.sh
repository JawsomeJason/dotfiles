#USAGE cmd "layers" help="List the layers in apply order with their repo, branch and local changes" {
#USAGE   flag "--names" help="Print only the layer names, one per line"
#USAGE }
cmd_layers() {
  if [ "${1:-}" = --names ]; then layers | cut -f1; return; fi
  layers | while IFS="$TAB" read -r name cfg; do
    root=$(layer_root "$cfg") || { say "$name  (source missing; config ${cfg:-default})"; continue; }
    branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
    remote=$(git -C "$root" config --get remote.origin.url 2>/dev/null)
    state=clean
    [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ] && state=dirty
    ahead=$(git -C "$root" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    [ "$ahead" != 0 ] && state="$state, $ahead unpushed"
    say "$name  ${root/#$HOME/~}  $branch  ${remote:-no remote}  ($state)"
  done
}
