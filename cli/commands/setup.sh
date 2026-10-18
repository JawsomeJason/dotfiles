# usage: dotfiles setup [-n] [-y] [--redo <step>|--redo-all] [--skip <step>] [--work yes|no] [--git-name <name>] [--git-email <email>] [--personal-email <email>] [--personal-host <host>] [--tailnet-domain <domain>] [--keychain-ref <op://...>] [--job-repo <owner/repo>]
# Sets up this machine one step at a time, asking only for what is missing. Safe to rerun.
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
