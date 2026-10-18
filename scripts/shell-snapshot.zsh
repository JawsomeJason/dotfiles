#!/bin/zsh
# Prints what an interactive zsh ends up with (aliases, functions, hooks, options, PATH, env),
# so a dotfiles change can be diffed against the shell it replaces. Env values are hashed,
# never printed, because several are secrets.
exec zsh -ic '
  _h() { print -rn -- "$1" | shasum -a 256 | cut -c1-12 }
  print "## aliases"; alias | sort
  print "## functions"
  for f in ${(ko)functions}; do [[ $f == _* && $f != _lcars* && $f != _cctab* ]] && continue; print "$f $(_h "$functions[$f]")"; done
  print "## hooks"; print "precmd: $precmd_functions"; print "preexec: $preexec_functions"; print "chpwd: $chpwd_functions"
  print "## options"; setopt | sort
  print "## path"; print -l $path
  print "## env"
  for v in ${(ko)parameters[(R)*export*]}; do [[ $v == (_|SHLVL|OLDPWD|PWD|TERM_SESSION_ID|SECURITYSESSIONID|TMPDIR|__CF*) ]] && continue; print "$v $(_h "${(P)v}")"; done
' 2>/dev/null
