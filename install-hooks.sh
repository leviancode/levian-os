#!/usr/bin/env sh
#
# Arm this clone's git hooks.
#
#     ./install-hooks.sh
#
# Git will not run anything in .githooks/ until core.hooksPath points there, and that setting is
# per-clone state git deliberately does not carry in the repository. There is no honest way around
# that: git runs nothing on clone, by design — a repository that could execute code on `git clone`
# would be a remote-code-execution vector. So this is one command, and it is the only one.
#
# It replaces the bare `git config core.hooksPath .githooks` the README used to ask for. Same effect,
# but it also says what got armed and checks the hooks are executable, which a config setting cannot
# do — a hook without its executable bit is skipped by git with a `hint:` you will not read, and a
# guard that silently does nothing is worse than no guard at all.
#
# Idempotent. Refuses to overwrite a core.hooksPath someone else set.

set -eu

cd "$(dirname "$0")"

if [ -t 1 ]; then
	G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; N=$'\033[0m'
else
	G=''; Y=''; R=''; D=''; N=''
fi
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '  %s✗%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

git rev-parse --git-dir >/dev/null 2>&1 || die "not a git clone — nothing to install into."
[ -d .githooks ] || die "no .githooks/ directory here."

current="$(git config --get core.hooksPath || true)"
if [ -n "$current" ] && [ "$current" != ".githooks" ]; then
	warn "core.hooksPath is already '$current' — left untouched."
	warn "   ${D}the guards in .githooks/ are NOT active. Unset it and re-run to install.${N}"
	exit 1
fi

git config core.hooksPath .githooks
ok "core.hooksPath → .githooks"

# The executable bit is the failure mode worth checking for: git skips a non-executable hook and only
# whispers about it. `git update-index --chmod` fixes the recorded mode, not just the working copy.
missing_x=0
for hook in .githooks/*; do
	[ -f "$hook" ] || continue
	name="${hook#.githooks/}"
	if [ -x "$hook" ]; then
		ok "$name ${D}→ armed${N}"
	else
		warn "$name ${D}→ NOT executable; git will skip it silently.${N}"
		warn "   ${D}fix with: chmod +x $hook && git update-index --chmod=+x $hook${N}"
		missing_x=1
	fi
done

[ "$missing_x" -eq 0 ] || die "one or more hooks are not executable — see above."

printf '\n%sDone.%s %sCommits are checked for format; pushes to protected branches are refused.%s\n' \
	"$G" "$N" "$D" "$N"
