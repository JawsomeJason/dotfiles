title="GitHub sign-in (gh)"
check() { gh auth status >/dev/null 2>&1; }
fix() {
  interactive || die "not signed in to GitHub; run gh auth login in a terminal"
  echo "Sign in with your personal GitHub account, so private layer repos can be cloned."
  gh auth login --hostname github.com --git-protocol https --web
}
