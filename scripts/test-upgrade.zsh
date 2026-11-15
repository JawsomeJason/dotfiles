#!/bin/zsh
# Checks the `upgrade` function in home/dot_zshrc.tmpl against stub tools. Never runs a real upgrade.
#   scripts/test-upgrade.zsh
root=${0:A:h:h}; t=$(mktemp -d); mkdir $t/bin; fails=0
eval "$(sed -n '/^function upgrade {/,/^}/p' $root/home/dot_zshrc.tmpl)"
export DOTFILES_UPGRADE_STEPS=$root/home/private_dot_config/dotfiles/upgrade-steps
for s in brew npm tldr; do printf '#!/bin/sh\necho "%s $*" >> %s/log\n[ %s = npm ] && exit 1\nexit 0\n' $s $t $s > $t/bin/$s; chmod +x $t/bin/$s; done
PATH=$t/bin; rehash
check() { # check <name> <expected exit> <output must contain> -- command...
  local name=$1 want=$2 pat=$3; shift 4; : > $t/log
  local out; out=$("$@" 2>&1); local rc=$?
  if (( rc == want )) && [[ $out$(<$t/log) == *${~pat}* ]]; then print "ok   $name"; else print "FAIL $name (exit $rc): $out"; (( fails++ )); fi
}
check "bare prints usage"      0 "usage: upgrade <list" -- upgrade
check "-h"                     0 "usage: upgrade <list" -- upgrade -h
check "list -h"                0 "usage: upgrade list"       -- upgrade list -h
check "run -h"                 0 "usage: upgrade run"        -- upgrade run --help
check "bare runs nothing"      0 "" -- upgrade; [[ -s $t/log ]] && { print "FAIL bare ran steps"; (( fails++ )) }
check "unknown verb"           2 "unknown verb"              -- upgrade nope
check "unknown flag"           2 "unknown option"            -- upgrade run --nope
check "list"                   0 "brew	brew upgrade"        -- upgrade list
check "list --missing"         0 "mas	mas"                 -- upgrade list --missing
check "run: failure, exit 1"   1 "failed: npm"               -- upgrade run
check "run: rest still ran"    1 "tldr --update"             -- upgrade run
check "--skip"                 0 "done"                      -- upgrade run --skip npm
check "--greedy reaches brew"  1 "brew upgrade --greedy"     -- upgrade run --greedy
check "no --greedy by default" 1 "brew upgrade"              -- upgrade run brew npm
[[ $(<$t/log) != *--greedy* ]] || { print "FAIL --greedy leaked into a default run"; (( fails++ )) }
check "named missing reported" 1 "not installed: mas"        -- upgrade run mas
exit $(( fails ? 1 : 0 ))
