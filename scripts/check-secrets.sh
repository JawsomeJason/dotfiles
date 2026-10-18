#!/bin/sh
# Exits 1 and names the file when a token-shaped string is found.
# --staged checks what is about to be committed; with no flag it checks every tracked file.
pattern='(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|figd_[A-Za-z0-9_-]{20,}|ATATT[A-Za-z0-9_=-]{20,}|AIza[0-9A-Za-z_-]{30,}|GOCSPX-[A-Za-z0-9_-]{10,}|squ_[a-f0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|sgai-[a-f0-9-]{20,}|xox[abcdpr]-[A-Za-z0-9-]{10,}|export [A-Z_]*(TOKEN|SECRET|PASSWORD|API_KEY|CLIENT_ID)=["'"'"']?[^"'"'"' $({]{8,})'
if [ "$1" = --staged ]; then
  hits=$(git diff --cached --name-only --diff-filter=ACM -z | xargs -0 git grep --cached -nIE "$pattern" -- 2>/dev/null)
else
  hits=$(git grep -nIE "$pattern" 2>/dev/null)
fi
[ -z "$hits" ] && exit 0
echo "Refusing: these lines look like secrets (values hidden):" >&2
echo "$hits" | cut -d: -f1,2 >&2
exit 1
