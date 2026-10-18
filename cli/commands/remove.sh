# usage: dotfiles remove [-n] [-l <layer>] [--keep-installed] [--no-push] <package>...
# Removes packages from whichever Brewfiles list them, uninstalls them, then commits and pushes.
#
# Every Brewfile on this machine is searched unless -l names one layer. --keep-installed only
# edits the Brewfile. Also available as dotfiles uninstall.
cmd_remove() {
  . "$DOTFILES_CLI/lib/brew.sh"
  keep=0 push=1 pkgs=''
  while [ $# -gt 0 ]; do
    case $1 in
      --keep-installed) keep=1 ;;
      --no-push) push=0 ;;
      -*) die "remove: unknown option $1 (see dotfiles help remove)" ;;
      *) pkgs="$pkgs $1" ;;
    esac
    shift
  done
  [ -n "$pkgs" ] || die "remove: name at least one package"
  files=$(brewfiles)
  if [ -n "$ONLY_LAYER" ]; then
    root=$("$DOTFILES_CLI/dotfiles" path "$ONLY_LAYER") || exit 1
    files=$(echo "$files" | grep "^$root/" || true)
  fi

  touched=''
  for p in $pkgs; do
    found=0
    for f in $files; do
      brewfile_lists "$f" "$p" || continue
      found=1
      if [ "$DRY_RUN" = 1 ]; then say "would: remove $p from ${f/#$HOME/~}"; continue; fi
      brew bundle remove --file "$f" "$p"
      git -C "$(dirname "$f")" add "$f"
      touched="$touched $(dirname "$f")"
    done
    [ $found = 1 ] || say "no Brewfile lists $p"
    if [ $keep = 0 ] && brew list "$p" >/dev/null 2>&1; then
      if [ "$DRY_RUN" = 1 ]; then say "would: brew uninstall $p"; else brew uninstall "$p"; fi
    fi
  done

  for root in $(printf '%s\n' $touched | sort -u); do
    git -C "$root" commit -q -m "Remove$pkgs from Brewfile"
    say "committed in ${root/#$HOME/~}"
    if [ $push = 1 ]; then git -C "$root" push -q && say "pushed"; fi
  done
}
