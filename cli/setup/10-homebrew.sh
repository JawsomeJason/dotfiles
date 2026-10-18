title="Homebrew"
check() {
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  command -v brew >/dev/null 2>&1
}
fix() {
  confirm "Install Homebrew? It asks for your password once." y || return 1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
