# usage: dotfiles sync [-n] [-l <layer>]
# Pulls each layer's repo (fast-forward only), then applies them all. With -n, fetches and previews.
cmd_sync() {
  selected_layers | while IFS="$TAB" read -r name cfg; do
    root=$(layer_root "$cfg") || die "$name: no git checkout behind its source"
    if [ "$DRY_RUN" = 1 ]; then
      note git -C "$root" fetch --quiet
      git -C "$root" fetch --quiet
      behind=$(git -C "$root" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo "?")
      say "$name: $behind commit(s) to pull"
    else
      note git -C "$root" pull --ff-only --quiet
      git -C "$root" pull --ff-only --quiet || die "$name: pull failed in $root (local commits or conflicts?)"
    fi
  done || exit 1
  . "$DOTFILES_CLI/commands/apply.sh"
  cmd_apply "$@"
}
