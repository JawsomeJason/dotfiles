title="chezmoi, gh and gum"
TOOLS="chezmoi gh gum"
check() {
  for t in $TOOLS; do command -v "$t" >/dev/null 2>&1 || return 1; done
}
fix() {
  missing=
  for t in $TOOLS; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
  # shellcheck disable=SC2086
  brew install $missing
}
