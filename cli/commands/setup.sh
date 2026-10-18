#USAGE cmd "setup" help="Set up this machine one step at a time, asking only for what is missing; safe to rerun" effect="write" {
#USAGE   flag "-y --yes" help="Take the default for every question instead of asking"
#USAGE   flag "--redo <step>" var=#true help="Run this step's fix even if its check passes"
#USAGE   flag "--redo-all" help="Run every step's fix"
#USAGE   flag "--skip <step>" var=#true help="Skip this step"
#USAGE   flag "--work <work>" help="Whether this is a work machine" {
#USAGE     choices "yes" "no"
#USAGE   }
#USAGE   flag "--git-name <name>" help="Git author name"
#USAGE   flag "--git-email <email>" help="Git author email (the employer's address on a work machine)"
#USAGE   flag "--personal-email <email>" help="Personal git email for personal repos"
#USAGE   flag "--personal-host <host>" help="Personal machine's short hostname, for ssh personal"
#USAGE   flag "--tailnet-domain <domain>" help="Domain that reaches tailnet machines by name"
#USAGE   flag "--keychain-ref <ref>" help="1Password op:// reference to the personal machine's login password"
#USAGE   flag "--job-repo <repo>" help="Shared work layer repo, as owner/name"
#USAGE }
#
# Each step is a file in cli/setup/NN-name.sh with a title, a check that reads the real state, and
# a fix. A step runs only when its check fails, so a stopped run picks up where it left off.
cmd_setup() {
  . "$DOTFILES_CLI/lib/prompt.sh"
  REDO='' REDO_ALL=0 SKIP=''
  while [ $# -gt 0 ]; do
    case $1 in
      -y|--yes) ASSUME_YES=1 ;;
      --redo) REDO="$REDO $2"; shift ;;
      --redo-all) REDO_ALL=1 ;;
      --skip) SKIP="$SKIP $2"; shift ;;
      --work) ANS_work=$2; shift ;;
      --git-name) ANS_gitName=$2; shift ;;
      --git-email) ANS_gitEmail=$2; shift ;;
      --personal-email) ANS_personalEmail=$2; shift ;;
      --personal-host) ANS_personalHost=$2; shift ;;
      --tailnet-domain) ANS_tailnetDomain=$2; shift ;;
      --keychain-ref) ANS_personalKeychainRef=$2; shift ;;
      --job-repo) ANS_jobRepo=$2; shift ;;
      *) die "setup: unknown option $1 (see dotfiles help setup)" ;;
    esac
    shift
  done
  export ASSUME_YES

  DOTFILES_REPO=$(cd "$DOTFILES_CLI/.." && pwd)
  CHEZMOI_CONFIG=$HOME/.config/chezmoi/chezmoi.toml

  for f in "$DOTFILES_CLI"/setup/[0-9]*.sh; do
    step=$(basename "$f" .sh); step=${step#*-}
    case " $SKIP " in *" $step "*) say "  skip  $step"; continue ;; esac
    unset -f check fix
    title=$step
    . "$f"
    forced=0
    { [ $REDO_ALL = 1 ] || case " $REDO " in *" $step "*) true ;; *) false ;; esac; } && forced=1
    if [ $forced = 0 ] && check; then say "  done  $title"; continue; fi
    if [ "$DRY_RUN" = 1 ]; then say "  todo  $title"; continue; fi
    say "  ...   $title"
    fix || die "step '$step' failed. Fix the cause and rerun dotfiles setup; finished steps are skipped."
    check || die "step '$step' still reports not done after its fix"
    say "  done  $title"
  done
}
