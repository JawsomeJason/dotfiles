# The usage spec (https://usage.jdx.dev) for dotfiles, assembled from #USAGE lines. Sourced, never run.
#
# Each built-in command file starts with its own #USAGE block; plugins (dotfiles-<x> on PATH) may
# carry one too, which is read from the file without running the plugin. help, the menu, docs/cli.md
# and zsh completion all come from this one spec.

usage_block() { sed -n 's/^#USAGE \{0,1\}//p' "$1"; }

# Plugin executables on PATH, first one wins: "<name>\t<path>" per line
plugins() {
  echo "$PATH" | tr ':' '\n' | while IFS= read -r d; do
    for f in "$d"/dotfiles-*; do if [ -x "$f" ]; then printf '%s\t%s\n' "${f##*/dotfiles-}" "$f"; fi; done
  done | awk -F'\t' '!seen[$1]++'
}

spec() {
  cat <<KDL
name "dotfiles"
bin "dotfiles"
$([ -n "${DOTFILES_SPEC_BASE_ONLY:-}" ] || printf 'version "%s"' "$(git -C "$DOTFILES_CLI/.." describe --tags --always 2>/dev/null || echo unknown)")
about "Apply the base dotfiles and every private layer with chezmoi"
flag "-n --dry-run" global=#true help="Preview without changing anything"
flag "-v --verbose" global=#true help="Print each chezmoi and git command"
flag "-l --layer <layer>" global=#true help="Act on one layer only" {
  choices run="dotfiles layers --names"
}
flag "-i --interactive" help="Open a menu of every command"
KDL
  for f in "$DOTFILES_CLI"/commands/[a-z]*.sh; do usage_block "$f"; done
  # DOTFILES_SPEC_BASE_ONLY=1 leaves out plugins and the version, for docs that must not depend on the machine
  [ -n "${DOTFILES_SPEC_BASE_ONLY:-}" ] && return
  plugins | while IFS="$TAB" read -r name path; do
    block=$(usage_block "$path")
    if [ -n "$block" ]; then echo "$block"
    else printf 'cmd "%s" help="Plugin %s (it describes no options)" {\n  arg "[args]..." help="Passed to the plugin as is"\n}\n' "$name" "${path/#$HOME/~}"
    fi
  done
}
