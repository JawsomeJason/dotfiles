# LCARS prompt: a row of pills, each an all-caps label on its color with its value on black,
# then input on its own line. A pill that won't fit moves whole to the next line, and the row
# re-lays itself out on resize. Warp draws its own prompt and ignores this one.
#   SSH   the host, when remote
#   PATH  the folder, or in a worktree the folder as if in the main repo
#   WT    the worktree
#   BR    the branch
#   PR    the branch's pull request and where it stands
#   DIFF  +added -removed lines, +N new files, ↑ to push, ↓ to pull; hidden when all is clean
#   NODE  wherever an .nvmrc applies: barely visible when right, red when it isn't
#   DUR   how long the last command ran, when 3s or more
#   JOBS  background jobs
#   ERR   the last command's exit code, when it failed
autoload -Uz add-zsh-hook
zmodload zsh/datetime

typeset -gA LCARS=(
  orange '#ff9900' gold '#ffcc66' lavender '#cc99cc' blue '#9999ff' ice '#99ccff'
  violet '#ddaadd' green '#99cc66' red '#ff2200' gray '#8888aa' dim '#3a3a4a' white '#ffffff'
)
LCARS_FETCH_MINUTES=5    # how stale the last git fetch can get before a background one
LCARS_PR_MINUTES=2       # how stale the cached PR status can get before gh refreshes it
LCARS_DUR_SECONDS=3      # how long a command runs before DUR shows
LCARS_CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/lcars-prompt

# Adds a pill: color, label, value as prompt markup (escape any % in plain text), then optionally
# the value's color (gold by default, unless the markup sets its own), the label's (black), and a
# URL that Cmd-click opens.
_lcars_pill() {
  _lcars_colors+=$1 _lcars_labels+=$2 _lcars_values+="%F{${4:-$LCARS[gold]}}$3" _lcars_inks+=${5:-0}
  _lcars_links+=$6
}

# True when the file is missing or older than the given minutes, and marks it fresh
_lcars_stale() {
  local fresh=($1(N.mm-$2))
  (( ! $#fresh )) && touch $1 2>/dev/null
}

_lcars_start() { _lcars_start=$EPOCHREALTIME }

_lcars_prompt() {
  local code=$?
  typeset -ga _lcars_colors=() _lcars_labels=() _lcars_values=() _lcars_inks=() _lcars_links=()
  typeset -g _lcars_code=$code
  [[ -n $SSH_CONNECTION ]] && _lcars_pill $LCARS[red] SSH "${(%):-%m}"
  _lcars_git
  _lcars_node
  if [[ -n $_lcars_start ]]; then
    local secs=${$(( EPOCHREALTIME - _lcars_start ))%.*}
    unset _lcars_start
    (( secs >= 60 )) && _lcars_pill $LCARS[gray] DUR "$(( secs / 60 ))m $(( secs % 60 ))s" ||
      { (( secs >= LCARS_DUR_SECONDS )) && _lcars_pill $LCARS[gray] DUR "${secs}s" }
  fi
  (( $#jobstates )) && _lcars_pill $LCARS[violet] JOBS $#jobstates
  (( code )) && _lcars_pill $LCARS[red] ERR $code '' $LCARS[white]
  _lcars_layout
}

# PATH, then WT, BR, PR and DIFF inside a repo
_lcars_git() {
  local where=${(%):-%~} dirs branch
  dirs=("${(@f)$(git rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>/dev/null)}")
  if [[ -z $dirs[3] ]]; then
    _lcars_pill $LCARS[orange] PATH "${where//\%/%%}"
    return
  fi
  local gitdir=$dirs[1] common=$dirs[2] top=$dirs[3]
  if [[ $gitdir != $common ]]; then
    _lcars_pill $LCARS[orange] PATH "${${${common:h}/#$HOME/~}//\%/%%}${PWD#$top}"
    _lcars_pill $LCARS[blue] WT "${${top:t}//\%/%%}"
  else
    _lcars_pill $LCARS[orange] PATH "${where//\%/%%}"
  fi
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
  [[ -n $branch ]] || return
  # BR links to the branch on GitHub when origin lives there
  local repo=$(git config remote.origin.url)
  repo=${${${repo/#git@github.com:/https://github.com/}%.git}:#^https://github.com/*}
  _lcars_pill $LCARS[lavender] BR "${branch//\%/%%}" '' '' ${repo:+$repo/tree/$branch}
  [[ $branch != (main|master) ]] && _lcars_pr $top $branch

  # Fetching in the background keeps ↓ current
  _lcars_stale $common/FETCH_HEAD $LCARS_FETCH_MINUTES &&
    (GIT_TERMINAL_PROMPT=0 git fetch --quiet --no-tags >/dev/null 2>&1 &)
  local st=("${(@f)$(git status --porcelain=v2 --branch 2>/dev/null)}") stats diff=()
  local untracked=${#${(M)st:#\?*}} changed=${#${(M)st:#[12u] *}} ahead=0 behind=0
  [[ ${(M)st:#\# branch.ab *} =~ '\+([0-9]+) -([0-9]+)' ]] && ahead=$match[1] behind=$match[2]
  if (( changed )); then
    stats=$(git diff HEAD --shortstat 2>/dev/null)
    [[ $stats =~ '([0-9]+) insertion' ]] && diff+="%F{green}+$match[1]"
    [[ $stats =~ '([0-9]+) deletion' ]] && diff+="%F{red}-$match[1]"
  fi
  (( untracked )) && diff+="%F{yellow}+$untracked"
  (( ahead )) && diff+="%F{cyan}↑$ahead"
  (( behind )) && diff+="%F{magenta}↓$behind"
  (( $#diff )) && _lcars_pill $LCARS[gray] DIFF "${(j: :)diff}"
}

# The PR pill comes from a cache gh refreshes in the background, so a change shows up one prompt
# after the refresh lands. The value carries the status.
_lcars_pr() {
  local f=$LCARS_CACHE/pr-${1//\//_}-${2//\//_} pr
  mkdir -p $LCARS_CACHE
  if _lcars_stale $f $LCARS_PR_MINUTES; then
    (gh pr view $2 --json number,state,isDraft,reviewDecision,statusCheckRollup,url --jq '
      [.number, .state, .isDraft, (.reviewDecision // ""),
       ([.statusCheckRollup[]? | (.conclusion // .state // "")] |
        if any(. == "FAILURE" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ERROR" or . == "ACTION_REQUIRED") then "FAIL"
        elif any(. == "" or . == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS" or . == "EXPECTED") then "PEND"
        else "PASS" end), .url] | @tsv' >$f.tmp 2>/dev/null || : >$f.tmp; mv -f $f.tmp $f) &!
  fi
  pr=(${(ps:\t:)"$(<$f)"})
  (( $#pr == 6 )) || return
  local stat color
  case $pr[2]:$pr[3]:$pr[5]:$pr[4] in
    MERGED:*)            stat=MRGD color=$LCARS[lavender] ;;
    CLOSED:*)            stat=SHUT color=$LCARS[gray] ;;
    *:true:*)            stat=DRFT color=$LCARS[gray] ;;
    *:FAIL:*)            stat=FAIL color=$LCARS[red] ;;
    *:CHANGES_REQUESTED) stat=CHGS color=$LCARS[red] ;;
    *:PEND:*)            stat=PEND ;;
    *:APPROVED)          stat=APPR color=$LCARS[green] ;;
    *)                   stat=OPEN ;;
  esac
  _lcars_pill $LCARS[ice] PR "#$pr[1] $stat" "$color" '' $pr[6]
}

_lcars_node() {
  local dir=$PWD want have
  while [[ $dir != / && ! -f $dir/.nvmrc ]]; do dir=${dir:h}; done
  [[ -f $dir/.nvmrc ]] || return
  want=${${"$(<$dir/.nvmrc)"//[[:space:]]/}#v}
  have=${${${(M)path:#*/.nvm/versions/node/*}[1]:h:t}#v}
  if [[ ! $want =~ '^[0-9.]+$' || $have == $want || $have == $want.* ]]; then
    _lcars_pill $LCARS[dim] NODE "${have:-?}" $LCARS[dim]
  else
    _lcars_pill $LCARS[red] NODE "${have:-?} (wants $want)" $LCARS[red]
  fi
}

# Lays the pills out for the current width. A pill wider than a whole line keeps the end of its
# value behind a leading … instead of breaking.
# The rounded caps are Nerd Font glyphs Supacode bundles.
_lcars_layout() {
  local left=$'' right=$'' line='' used=0 i c v w max pw
  for (( i = 1; i <= $#_lcars_colors; i++ )); do
    # Visible width: the markup without its color codes, with %% counting as one %
    c=$_lcars_colors[i] v=$_lcars_values[i] w=${#${${(S)v//\%F\{*\}}//\%\%/%}}
    max=$(( COLUMNS - ${#_lcars_labels[i]} - 5 ))
    # One color code means plain text, safe to cut down
    if (( w > max && max > 1 )) && [[ ${v#\%F\{*\}} != *%F\{* ]]; then
      v="${(M)v#\%F\{*\}}…${v: -$(( max - 1 ))}" w=$max
    fi
    pw=$(( ${#_lcars_labels[i]} + w + 5 ))
    if (( used && used + 1 + pw > COLUMNS )); then
      line+=$'\n' used=0
    elif (( used )); then
      line+=' ' used=$(( used + 1 ))
    fi
    # A link wraps the value in an OSC 8 hyperlink
    [[ -n $_lcars_links[i] ]] && v="%{"$'\e]8;;'"${_lcars_links[i]//\%/%%}"$'\e\\'"%}$v%{"$'\e]8;;\e\\'"%}"
    line+="%F{$c}$left%K{$c}%F{$_lcars_inks[i]}$_lcars_labels[i] %k $v %F{$c}$right%f"
    used=$(( used + pw ))
  done
  PROMPT=$'\n'"$line"$'\n'"%F{$(( _lcars_code ? 1 : 5 ))}❯%f "
}
TRAPWINCH() { _lcars_layout; zle && zle reset-prompt }

add-zsh-hook preexec _lcars_start
add-zsh-hook precmd _lcars_prompt
