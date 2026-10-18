# Interactive menu built from the usage spec (hidden; opened by bare `dotfiles` in a terminal, or -i).
# Pick a command, pick which of its options to set, answer only those, see the equivalent command
# line, then run it. New commands and plugins with a #USAGE block appear here without menu code.
cmd__menu() {
  . "$DOTFILES_CLI/lib/spec.sh"
  . "$DOTFILES_CLI/lib/prompt.sh"
  has_gum || die "the menu needs gum (brew install gum); run dotfiles help for the commands"
  command -v usage >/dev/null 2>&1 || die "the menu needs usage (brew install usage)"
  json=$(spec | usage generate json -f -) || die "could not read the usage spec"

  # Fields are split on the unit separator: a tab would merge empty fields and shift the rest
  US=$(printf '\037')
  path=.cmd words=() globals=() opts=() argv=()
  while [ "$(jq "$path.subcommands | length" <<<"$json")" -gt 0 ]; do
    choice=$(jq -r "$path.subcommands | to_entries[] | select(.value.hide | not) | \"\(.key)\t\(.value.help // \"\")\"" <<<"$json" |
      awk -F'\t' '{ printf "%-10s %s\n", $1, $2 }' |
      gum filter --placeholder "Type to filter, enter to choose" --header "dotfiles ${words[*]:-}" --height 20) || exit 130
    name=${choice%% *}
    words+=("$name")
    path="$path.subcommands[\"$name\"]"
  done

  # The command's own flags, then the global ones that make sense to set from here
  rows=$(jq -r "[($path.flags[] | . + {scope: \"own\"}), (.cmd.flags[] | select(.global) | . + {scope: \"global\"})]
    | .[] | select(.hide | not)
    | [(if .long[0] then \"--\" + .long[0] else \"-\" + .short[0] end), .scope, (if .arg then \"value\" else \"switch\" end),
       ((.var // false) | tostring), ((.arg.choices.choices // []) | join(\",\")), (.arg.choices.run // \"\"), (.help // \"\")]
    | join(\"\\u001f\")" <<<"$json")
  if [ -n "$rows" ]; then
    picked=$(printf '%s\n' "$rows" | awk -F'\037' '{ printf "%-22s %s\n", $1, $7 }' |
      gum choose --no-limit --header "Options to set (space selects, enter continues; none is fine)") || true
    printf '%s\n' "$picked" | while IFS= read -r line; do [ -n "$line" ] && echo "${line%% *}"; done > "${TMPDIR:-/tmp}/dotfiles-menu.$$"
    while IFS="$US" read -r flag scope kind var choices run help; do
      grep -qx -- "$flag" "${TMPDIR:-/tmp}/dotfiles-menu.$$" || continue
      if [ "$kind" = switch ]; then values=on
      else values=$(menu_value "$flag" "$var" "$choices" "$run" "$help") || exit 130; fi
      [ -n "$values" ] || continue
      while IFS= read -r v; do
        [ -n "$v" ] || continue
        if [ "$scope" = global ]; then
          if [ "$kind" = switch ]; then globals+=("$flag"); else globals+=("$flag" "$v"); fi
        else
          if [ "$kind" = switch ]; then opts+=("$flag"); else opts+=("$flag" "$v"); fi
        fi
      done <<<"$values"
    done <<<"$rows"
    rm -f "${TMPDIR:-/tmp}/dotfiles-menu.$$"
  fi

  while IFS="$US" read -r arg required var choices run help; do
    [ -n "$arg" ] || continue
    if [ "$required" != true ] && ! gum confirm --default=false "Set $arg? ($help)"; then continue; fi
    values=$(menu_value "$arg" "$var" "$choices" "$run" "$help") || exit 130
    [ -n "$values" ] || { [ "$required" = true ] && die "$arg is required"; continue; }
    while IFS= read -r v; do
      if [ "$var" = true ] && [ -z "$choices$run" ]; then
        # Free-form lists are typed space separated
        for w in $v; do argv+=("$w"); done
      else argv+=("$v"); fi
    done <<<"$values"
  done < <(jq -r "$path.args[]? | [.name, ((.required // false) | tostring), ((.var // false) | tostring),
    ((.choices.choices // []) | join(\",\")), (.choices.run // \"\"), (.help // \"\")] | join(\"\\u001f\")" <<<"$json")

  line=(dotfiles ${globals[@]+"${globals[@]}"} "${words[@]}" ${opts[@]+"${opts[@]}"} ${argv[@]+"${argv[@]}"})
  printf '\n  %s\n\n' "$(printf '%q ' "${line[@]}")"
  gum confirm "Run it?" || exit 0
  exec "$DOTFILES_CLI/dotfiles" "${line[@]:1}"
}

# Asks for one value: a picker when the spec lists choices (or a command that prints them), else a
# text box. Prints one value per line; repeatable options may return several.
menu_value() {
  _name=$1 _var=$2 _choices=$3 _run=$4 _help=$5
  _limit=--limit=1
  [ "$_var" = true ] && _limit=--no-limit
  if [ -n "$_choices" ]; then
    printf '%s\n' "$_choices" | tr ',' '\n' | gum choose $_limit --header "$_name: $_help"
  elif [ -n "$_run" ]; then
    sh -c "$_run" | gum choose $_limit --header "$_name: $_help"
  else
    gum input --header "$_name" --placeholder "$_help" --width 0
  fi
}
