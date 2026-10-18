#USAGE cmd "help" help="List commands, or show one command's usage" {
#USAGE   arg "[command]" help="Command to describe"
#USAGE }
# Renders help from the usage spec (lib/spec.sh), so help never drifts from the specs.
cmd_help() {
  . "$DOTFILES_CLI/lib/spec.sh"
  _spec=$(spec)
  if [ $# -gt 0 ]; then
    # An alias (dotfiles help uninstall) describes the command it belongs to
    want=$(printf '%s\n' "$_spec" | awk -v want="$1" '/^cmd "/ { split($0, p, "\""); c = p[2] } /^  alias "/ { split($0, p, "\""); if (p[2] == want) print c }')
    awk -v want="${want:-$1}" "$SPEC_HELP_AWK" <<SPEC
$_spec
SPEC
    return
  fi
  awk '
    function attr(line, key,   m) { if (match(line, key "=\"([^\"\\\\]|\\\\.)*\"")) { m = substr(line, RSTART + length(key) + 2, RLENGTH - length(key) - 3); gsub(/\\"/, "\"", m); return m } return "" }
    /^about / { sub(/^about "/, ""); sub(/"$/, ""); about = $0 }
    /^cmd "/ { split($0, p, "\""); cmds[++n] = sprintf("  %-10s %s", p[2], attr($0, "help")) }
    /^flag "/ { split($0, p, "\""); flags[++m] = sprintf("  %-22s %s", p[2], attr($0, "help")) }
    END {
      print "usage: dotfiles [options] [command] [args]\n"
      print about "\n\ncommands:"
      for (i = 1; i <= n; i++) print cmds[i]
      print "\noptions:"
      for (i = 1; i <= m; i++) print flags[i]
      print "  -h, --help             Show help (dotfiles help <command> for one command)"
      print "  -V, --version          Print the version"
      print "\nWith no command in a terminal, or with -i, dotfiles opens a menu of every command."
    }' <<SPEC
$_spec
SPEC
}

# Prints one command's block of the spec as help: its usage line, flags, arguments and subcommands
SPEC_HELP_AWK='
  function attr(line, key,   m) { if (match(line, key "=\"([^\"\\\\]|\\\\.)*\"")) { m = substr(line, RSTART + length(key) + 2, RLENGTH - length(key) - 3); gsub(/\\"/, "\"", m); return m } return "" }
  function q(line,   p) { split(line, p, "\""); return p[2] }
  !inside && /^cmd "/ {
    name = q($0)
    hit = (name == want)
    if (!hit && match($0, /\{$/)) { depth = 1; skip = 1; next }
  }
  skip { if ($0 ~ /\{$/) depth++; if ($0 ~ /^ *\}$/) depth--; if (depth == 0) skip = 0; next }
  !inside && hit {
    found = 1; help = attr($0, "help"); inside = ($0 ~ /\{$/); depth = inside; hit = 0
    next
  }
  inside {
    if ($0 ~ /^ *\}$/) { depth--; if (depth == 0) inside = 0; next }
    if (depth == 1 && $0 ~ /^ *alias "/) next
    if (depth == 1 && $0 ~ /^ *flag "/) flags[++nf] = sprintf("  %-26s %s", q($0), attr($0, "help"))
    if (depth == 1 && $0 ~ /^ *arg "/) { args[++na] = sprintf("  %-26s %s", q($0), attr($0, "help")); synopsis = synopsis " " q($0) }
    if (depth == 1 && $0 ~ /^ *cmd "/) { subs[++ns] = sprintf("  %-26s %s", q($0), attr($0, "help")); hassub = 1 }
    if ($0 ~ /^ *choices /) { c = $0; sub(/^ *choices /, "", c); gsub(/"/, "", c); if (c ~ /^run=/) { sub(/^run=/, "", c); c = "values from: " c }; if (last == "arg") args[na] = args[na] " (" c ")"; else if (last == "flag") flags[nf] = flags[nf] " (" c ")" }
    if (depth == 1 && $0 ~ /^ *flag "/) last = "flag"
    if (depth == 1 && $0 ~ /^ *arg "/) last = "arg"
    if ($0 ~ /\{$/) depth++
  }
  END {
    if (!found) { print "dotfiles: no command named \"" want "\" (see dotfiles help)" > "/dev/stderr"; exit 1 }
    printf "usage: dotfiles %s%s%s%s\n\n%s\n", want, (nf ? " [flags]" : ""), (hassub ? " <command>" : ""), synopsis, help
    if (ns) { print "\ncommands:"; for (i = 1; i <= ns; i++) print subs[i] }
    if (nf) { print "\nflags:"; for (i = 1; i <= nf; i++) print flags[i] }
    if (na) { print "\narguments:"; for (i = 1; i <= na; i++) print args[i] }
    print "\nGlobal options -n, -v and -l work with every command."
  }'
