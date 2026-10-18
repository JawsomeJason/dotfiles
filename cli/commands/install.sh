# usage: dotfiles install [-n] [-l <layer>] [--personal] [--cask] [--no-push] <package>...
# Installs packages with Homebrew and records them in a layer's Brewfile, then commits and pushes it.
#
# The base layer is the default, so the package lands on every machine; -l job or -l <employer>
# keeps it to work machines, and --personal to personal machines (the base's Brewfile.personal).
# Casks are detected; --cask forces one. Packages a Brewfile already lists are only installed.
cmd_install() {
  . "$DOTFILES_CLI/lib/brew.sh"
  cask=0 push=1 personal=0 pkgs=''
  while [ $# -gt 0 ]; do
    case $1 in
      --cask) cask=1 ;;
      --personal) personal=1 ;;
      --no-push) push=0 ;;
      -*) die "install: unknown option $1 (see dotfiles help install)" ;;
      *) pkgs="$pkgs $1" ;;
    esac
    shift
  done
  [ -n "$pkgs" ] || die "install: name at least one package"
  layer=${ONLY_LAYER:-base}
  [ $personal = 1 ] && [ "$layer" != base ] && die "--personal only applies to the base layer"
  cfg=$(layers | awk -F'\t' -v want="$layer" '$1 == want { print $2; found = 1 } END { exit !found }') ||
    die "no layer named '$layer' (see dotfiles layers)"
  root=$(layer_root "$cfg") || die "$layer: no git checkout behind its source"
  file=$root/Brewfile
  [ $personal = 1 ] && file=$root/Brewfile.personal

  added=''
  for p in $pkgs; do
    kind=formula
    if [ $cask = 1 ] || { ! brew info --formula "$p" >/dev/null 2>&1 && brew info --cask "$p" >/dev/null 2>&1; }; then kind=cask; fi
    flag=''; [ $kind = cask ] && flag=--cask
    if [ "$DRY_RUN" = 1 ]; then
      say "would: brew install $flag $p"
    else
      # shellcheck disable=SC2086
      brew install $flag "$p" || die "brew could not install $p"
    fi
    if brewfile_lists "$file" "$p"; then
      say "${file/#$HOME/~} already lists $p"
    elif [ "$DRY_RUN" = 1 ]; then
      say "would: add $kind $p to ${file/#$HOME/~}"
    else
      # shellcheck disable=SC2086
      brew bundle add $flag --file "$file" "$p"
      added="$added $p"
    fi
  done

  [ -n "$added" ] || return 0
  git -C "$root" add "$file"
  git -C "$root" commit -q -m "Add$added to $(basename "$file")"
  say "committed in ${root/#$HOME/~}"
  if [ $push = 1 ]; then git -C "$root" push -q && say "pushed"; fi
}
