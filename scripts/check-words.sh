#!/bin/sh
# Exits 1 and names the location when a forbidden word appears. Never prints the word itself,
# not even inside a path, because CI logs on a public repo are public.
#
# Words come from ~/.config/dotfiles/forbidden-words.d/* (one per line, # comments allowed), which
# private layers install, plus $FORBIDDEN_WORDS (comma or newline separated), which CI reads from
# a repository secret. Matching ignores case.
#
#   --staged          staged file contents and names, plus the author and committer identity
#   --message <file>  a commit message (the commit-msg hook)
#   --tree            every tracked file and path
#   --history         every commit on every ref: messages, identities, file contents and names,
#                     plus tag messages
#   --revs <revs>     like --history, but only commits reachable from these revisions
#                     (space separated, rev-list syntax); the pre-push hook passes what it pushes
#   --require-words   fail when no words are configured; implied on a work machine
#                     (DOTFILES_WORK=true in ~/.config/dotfiles/env)
set -u

words=$(mktemp)
hits=$(mktemp)
trap 'rm -f "$words" "$hits"' EXIT

dir=${DOTFILES_WORDS_DIR:-$HOME/.config/dotfiles/forbidden-words.d}
{
  [ -d "$dir" ] && cat "$dir"/* 2>/dev/null
  printf '%s\n' "${FORBIDDEN_WORDS:-}" | tr ',' '\n'
} | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort -u > "$words"

require=0
grep -qx 'DOTFILES_WORK=true' "$HOME/.config/dotfiles/env" 2>/dev/null && require=1
modes=
revs=--all
while [ $# -gt 0 ]; do
  case $1 in
    --require-words) require=1 ;;
    --message) modes="$modes message"; message_file=$2; shift ;;
    --revs) modes="$modes history"; revs=$2; shift ;;
    --staged|--tree|--history) modes="$modes ${1#--}" ;;
    -h|--help) sed -n '2,19s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "check-words: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$modes" ] || modes=tree

if [ ! -s "$words" ]; then
  if [ $require = 1 ]; then
    echo "check-words: no forbidden words configured (set FORBIDDEN_WORDS or $dir)" >&2
    exit 2
  fi
  echo "check-words: no forbidden words configured here, skipping" >&2
  exit 0
fi

match() { grep -qiF -f "$words"; }

for mode in $modes; do
  case $mode in
    staged)
      git diff --cached --name-only --diff-filter=ACMR -z |
        xargs -0 git grep --cached -niIF -f "$words" -- 2>/dev/null | cut -d: -f1,2 >> "$hits"
      git diff --cached --name-only --diff-filter=ACMR | match && echo "a staged path name" >> "$hits"
      { git var GIT_AUTHOR_IDENT; git var GIT_COMMITTER_IDENT; } | match &&
        echo "commit identity (git config user.name or user.email)" >> "$hits"
      ;;
    message)
      grep -v '^#' "$message_file" | match && echo "commit message" >> "$hits"
      ;;
    tree)
      git grep -niIF -f "$words" 2>/dev/null | cut -d: -f1,2 >> "$hits"
      git ls-files | match && echo "a tracked path name" >> "$hits"
      ;;
    history)
      # shellcheck disable=SC2086
      for sha in $(git rev-list $revs); do
        git show -s --format='%an%n%ae%n%cn%n%ce%n%B' "$sha" | match &&
          echo "commit $sha: message or identity" >> "$hits"
        git ls-tree -r --name-only "$sha" | match && echo "commit $sha: a path name" >> "$hits"
      done
      # shellcheck disable=SC2086
      git rev-list $revs | xargs git grep -ilIF -f "$words" 2>/dev/null | cut -c1-7 |
        sed 's/^/commit /; s/$/: file contents/' >> "$hits"
      if [ "$revs" = --all ]; then
        for tag in $(git tag); do
          git cat-file -p "$tag" | match && echo "tag $tag" >> "$hits"
        done
      fi
      ;;
  esac
done

[ -s "$hits" ] || exit 0
echo "Refusing: forbidden words found (words hidden):" >&2
sort -u "$hits" | while IFS= read -r line; do
  if printf '%s\n' "$line" | match; then echo "a location whose path contains a forbidden word"; else echo "$line"; fi
done | sort -u >&2
exit 1
