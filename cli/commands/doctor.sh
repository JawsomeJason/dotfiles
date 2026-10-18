#USAGE cmd "doctor" help="Check every layer, the machine's answers, forbidden words and Homebrew drift; reports only, changes nothing" {
#USAGE   flag "--offline" help="Skip the checks that talk to GitHub"
#USAGE }
# Exits 1 when anything needs attention, so scripts can use it as a health check.
cmd_doctor() {
  . "$DOTFILES_CLI/lib/brew.sh"
  offline=0
  [ "${1:-}" = --offline ] && offline=1
  problems=0
  ok() { printf '  ok    %s\n' "$*"; }
  bad() { printf '  FIX   %s\n' "$*"; problems=$((problems + 1)); }
  info() { printf '  note  %s\n' "$*"; }

  echo "tools"
  for t in chezmoi git brew gh usage gum jq; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t is not installed"; fi
  done

  echo "layers"
  while IFS="$TAB" read -r name cfg; do
    root=$(layer_root "$cfg") || { bad "$name: source missing (config ${cfg:-default})"; continue; }
    hooks=$(git -C "$root" config core.hooksPath)
    [ "$hooks" = .githooks ] || bad "$name: git hooks are off in ${root/#$HOME/~} (dotfiles apply turns them on)"
    if [ -n "$(git -C "$root" status --porcelain)" ]; then info "$name: uncommitted changes in ${root/#$HOME/~}"; fi
    remote=$(git -C "$root" config --get remote.origin.url)
    if [ -z "$remote" ]; then bad "$name: no origin remote"
    elif [ $offline = 0 ]; then
      branch=$(git -C "$root" rev-parse --abbrev-ref HEAD)
      upstream=$(git -C "$root" ls-remote origin "refs/heads/$branch" 2>/dev/null | cut -f1)
      head=$(git -C "$root" rev-parse HEAD)
      if [ -z "$upstream" ]; then bad "$name: cannot reach $remote, or it has no $branch branch"
      elif [ "$upstream" = "$head" ]; then ok "$name: ${root/#$HOME/~} matches origin/$branch"
      elif git -C "$root" merge-base --is-ancestor "$upstream" "$head" 2>/dev/null; then info "$name: local commits not pushed yet"
      else bad "$name: origin/$branch has commits this checkout lacks (dotfiles sync)"; fi
    else ok "$name: ${root/#$HOME/~}"; fi
  done < <(layers)

  echo "files"
  dupes=$(layers | while IFS="$TAB" read -r name cfg; do
    layer_chezmoi "$cfg" managed --include files,symlinks --path-style absolute 2>/dev/null | sed "s|^|$name$TAB|"
  done | sort -t "$TAB" -k2 | awk -F'\t' '$2 == prev { print "  " $2 } { prev = $2 }' | sort -u)
  if [ -z "$dupes" ]; then ok "every file has one owner"; else bad "files owned by more than one layer:"; echo "$dupes"; fi
  pending=$(layers | while IFS="$TAB" read -r name cfg; do layer_chezmoi "$cfg" status 2>/dev/null | sed "s|^|$name: |"; done)
  if [ -z "$pending" ]; then ok "home folder matches every layer"; else info "dotfiles apply would change:"; echo "$pending" | sed 's/^/        /'; fi

  echo "answers"
  env_file=$HOME/.config/dotfiles/env
  if [ -f "$env_file" ]; then ok "${env_file/#$HOME/~}"; else bad "${env_file/#$HOME/~} is missing (dotfiles apply writes it)"; fi
  work=$(grep -x 'DOTFILES_WORK=true' "$env_file" 2>/dev/null)
  words=$(cat "$HOME"/.config/dotfiles/forbidden-words.d/* 2>/dev/null | grep -v '^#' | grep -c . || true)
  if [ -n "$work" ] && [ "$words" -eq 0 ]; then bad "work machine with no forbidden words installed (commits will be refused)"
  elif [ "$words" -gt 0 ]; then ok "$words forbidden words installed"
  else info "no forbidden words here (fine on a personal machine; CI still checks)"; fi
  base=$("$DOTFILES_CLI/dotfiles" path 2>/dev/null)
  if [ -n "$base" ] && [ "$words" -gt 0 ]; then
    if (cd "$base" && scripts/check-words.sh --tree >/dev/null 2>&1); then ok "no forbidden words in the base repo"
    else bad "forbidden words in the base repo (run scripts/check-words.sh --tree there)"; fi
  fi

  echo "packages"
  if command -v brew >/dev/null 2>&1; then
    all=$(mktemp)
    for f in $(brewfiles); do
      cat "$f" >> "$all"
      missing=$(brew bundle check --no-upgrade --verbose --file "$f" 2>&1 | grep -c "needs to be" || true)
      if [ "$missing" -eq 0 ]; then ok "${f/#$HOME/~}"; else bad "${f/#$HOME/~}: $missing missing (dotfiles setup installs them)"; fi
    done
    extra=$(brew bundle cleanup --file "$all" 2>/dev/null | grep -vE '^(Would|Run )' | grep -v '^$' || true)
    rm -f "$all"
    if [ -z "$extra" ]; then ok "nothing installed outside the Brewfiles"
    else info "installed but in no Brewfile (dotfiles install to keep, dotfiles remove to drop):"; echo "$extra" | sed 's/^/        /'; fi
  fi

  echo
  if [ $problems -eq 0 ]; then echo "All good."; else echo "$problems thing(s) to fix."; return 1; fi
}
