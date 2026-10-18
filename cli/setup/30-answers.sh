title="machine answers in ~/.config/chezmoi/chezmoi.toml"
KEYS="work gitName gitEmail personalHost tailnetDomain personalKeychainRef"
cfg_has() { [ -f "$CHEZMOI_CONFIG" ] && grep -q "^[[:space:]]*$1 = " "$CHEZMOI_CONFIG"; }
cfg_get() { sed -n "s/^[[:space:]]*$1 = //p" "$CHEZMOI_CONFIG" | head -1 | sed 's/^"//; s/"$//'; }
toml_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
check() {
  [ -f "$CHEZMOI_CONFIG" ] || return 1
  for k in $KEYS; do cfg_has "$k" || return 1; done
  [ "$(cfg_get sourceDir)" = "$DOTFILES_REPO" ]
}
fix() {
  for k in $KEYS; do
    eval "v=\${ANS_$k:-}"
    if [ -z "$v" ] && cfg_has "$k"; then eval "ANS_$k=\$(cfg_get $k)"; eval "have_$k=1"; else eval "have_$k=0"; fi
    [ -n "$v" ] && eval "have_$k=1"
  done
  if [ "$have_work" = 0 ]; then
    if confirm "Is this a work machine?" n; then ANS_work=true; else ANS_work=false; fi
  fi
  case $ANS_work in yes|y|true) ANS_work=true ;; *) ANS_work=false ;; esac
  [ "$have_gitName" = 1 ] || ask ANS_gitName "Git author name" "Jason Featheringham"
  if [ "$have_gitEmail" = 1 ]; then :
  elif [ "$ANS_work" = true ]; then ask ANS_gitEmail "Git author email (the employer's address on a work machine)" ""
  else ask ANS_gitEmail "Git author email" "thejase@gmail.com"; fi
  require ANS_gitEmail "the git author email" --git-email
  [ "$have_personalHost" = 1 ] || ask ANS_personalHost "Personal machine's short hostname, for ssh personal (blank for none)" ""
  [ "$have_tailnetDomain" = 1 ] || ask ANS_tailnetDomain "Domain that reaches tailnet machines by name (blank for none)" ""
  [ "$have_personalKeychainRef" = 1 ] || ask ANS_personalKeychainRef "1Password op:// reference to the personal machine's login password (blank for none)" ""

  mkdir -p "$(dirname "$CHEZMOI_CONFIG")"
  [ -f "$CHEZMOI_CONFIG" ] && cp "$CHEZMOI_CONFIG" "$CHEZMOI_CONFIG.before-setup"
  {
    echo "sourceDir = $(toml_str "$DOTFILES_REPO")"
    echo
    echo "[data]"
    echo "  work = $ANS_work"
    for k in gitName gitEmail personalHost tailnetDomain personalKeychainRef; do
      eval "v=\${ANS_$k:-}"
      echo "  $k = $(toml_str "$v")"
    done
  } > "$CHEZMOI_CONFIG"
  chezmoi init --source "$DOTFILES_REPO"
}
