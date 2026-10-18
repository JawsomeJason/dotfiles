#USAGE cmd "hosts" help="List tailnet machines with your descriptions and whether each is online" {
#USAGE   flag "--json" help="Print JSON instead of a table"
#USAGE }
# Descriptions come from ~/.config/dotfiles/devices, one `name = description` per line, which stays
# on this machine. Tailscale itself has no field for them.
cmd_hosts() {
  command -v tailscale >/dev/null 2>&1 || die "tailscale is not installed"
  devices=$HOME/.config/dotfiles/devices
  status=$(tailscale status --json) || die "tailscale is not running"
  jq -r --rawfile desc "${devices}" --arg json "${1:-}" '
    def descs: ($desc | split("\n") | map(select(test("^[^#].*=")) | capture("^(?<k>[^=]+?)\\s*=\\s*(?<v>.*)$")) | map({(.k | ascii_downcase): .v}) | add) // {};
    def row($self): {name: (.DNSName | split(".")[0]), os: (.OS // ""), online: (if $self then true else (.Online // false) end),
      last_seen: (.LastSeen // ""), self: $self};
    descs as $d
    | ([.Self | row(true)] + [.Peer[]? | row(false)])
    | map(. + {description: ($d[.name] // "")})
    | sort_by(.name)
    | if $json == "--json" then . else
        (["NAME", "DESCRIPTION", "OS", "STATUS"] | @tsv),
        (.[] | [.name + (if .self then " (this machine)" else "" end), (if .description == "" then "-" else .description end),
                (if .os == "" then "-" else .os end), (if .online then "online" else "offline" end)] | @tsv)
      end' <<<"$status" 2>/dev/null | if [ "${1:-}" = --json ]; then cat; else column -t -s "$TAB"; fi || { [ -f "$devices" ] || die "no ${devices/#$HOME/~} yet: add lines like 'lcars = NAS'"; die "could not read tailscale status"; }
}
