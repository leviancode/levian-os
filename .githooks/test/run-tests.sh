#!/usr/bin/env bash
#
# Test suite for the Levian OS pre-commit guard (../pre-commit).
#
#     .githooks/test/run-tests.sh
#
# Every case builds a throwaway repository in a temp directory, installs the
# hook into it, and drives a real `git commit`. Nothing here touches the working
# repository or its identity.
#
# These are POSITIVE controls above all else. A guard that is silently doing
# nothing passes any test that only asserts "a clean commit succeeds" — which is
# exactly how the credential scan came to be a no-op: its pattern begins with
# '-----BEGIN', grep parsed that as a bundle of short flags, exited 2 having
# scanned nothing, and the hook returned 0. Green the whole way down.
#
# So each protection is proven to FIRE: a violation is staged, and the case
# asserts a non-zero exit, that zero commits were created, and that the failure
# came from the check under test rather than from some other check tripping
# first. The credential cases additionally assert that grep never emitted an
# option-parsing error, which is the specific footprint of that bug.
#
# Credential fixtures are assembled from string fragments at runtime, so the
# literal secrets never appear in this file and it can survive its own guard.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hook="$here/../pre-commit"

[ -x "$hook" ] || { printf 'cannot find an executable hook at %s\n' "$hook" >&2; exit 1; }

if [ -t 1 ]; then
	c_green=$'\033[32m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
else
	c_green=''; c_red=''; c_dim=''; c_off=''
fi

n_pass=0
n_fail=0
tmpdirs=()
commit_err=''
commit_rc=0
commit_count=''

cleanup() { [ ${#tmpdirs[@]} -gt 0 ] && rm -rf "${tmpdirs[@]}"; }
trap cleanup EXIT

ok()  { n_pass=$((n_pass + 1)); printf '  %sPASS%s  %s\n' "$c_green" "$c_off" "$1"; }
bad() {
	n_fail=$((n_fail + 1))
	printf '  %sFAIL%s  %s\n' "$c_red" "$c_off" "$1"
	printf '        %s%s%s\n' "$c_dim" "$2" "$c_off"
}

# A throwaway repo with the hook installed, a fixture marker list, and an
# identity that is clean against it. Echoes the path.
new_repo() {
	local d
	d="$(mktemp -d)"
	tmpdirs+=("$d")
	git -c init.defaultBranch=main init -q "$d"
	mkdir -p "$d/.githooks"
	cp "$hook" "$d/.githooks/pre-commit"
	chmod +x "$d/.githooks/pre-commit"
	git -C "$d" config core.hooksPath .githooks
	git -C "$d" config commit.gpgsign false
	git -C "$d" config user.name "Clean Committer"
	git -C "$d" config user.email "1+clean@users.noreply.github.com"
	cat > "$d/.personal-markers" <<'EOF'
# fixture marker list — placeholders only
ACME_CORP
PROJECT_ZEPHYR
private@example.invalid
EOF
	printf '%s' "$d"
}

# Run `git commit` in a repo, capturing exit code, stderr, and the resulting
# commit count. Repos start empty, so a blocked commit must leave count at 0.
attempt_commit() {
	local d="$1"; shift
	commit_err="$(git -C "$d" commit -m "guard test" "$@" 2>&1 >/dev/null)"
	commit_rc=$?
	commit_count="$(git -C "$d" rev-list --count --all 2>/dev/null || printf 'ERR')"
}

expect_block() {
	local label="$1"
	if [ "$commit_rc" -eq 0 ]; then
		bad "$label" "guard did not fire: commit succeeded (rc=0, commits=$commit_count)"
	elif [ "$commit_count" != "0" ]; then
		bad "$label" "blocked (rc=$commit_rc) but $commit_count commit(s) were created"
	else
		ok "$label"
	fi
}

expect_allow() {
	local label="$1"
	if [ "$commit_rc" -ne 0 ]; then
		bad "$label" "false positive: rc=$commit_rc${commit_err:+ — ${commit_err%%$'\n'*}}"
	elif [ "$commit_count" != "1" ]; then
		bad "$label" "rc=0 but commit count is $commit_count, wanted 1"
	else
		ok "$label"
	fi
}

# Proves the right check fired, not merely that something did.
expect_reason() {
	local label="$1" needle="$2"
	case "$commit_err" in
		*"$needle"*) ok "$label" ;;
		*) bad "$label" "stderr did not mention '$needle'; got: $(printf '%s' "$commit_err" | tr '\n' ' ' | cut -c1-160)" ;;
	esac
}

# The signature of the flag-parsing bug: grep rejecting its own pattern.
expect_no_grep_option_error() {
	local label="$1"
	if printf '%s' "$commit_err" |
		grep -qiE 'invalid option|unrecognized option|illegal option|usage: *grep'; then
		bad "$label" "grep rejected the pattern as a flag: $(printf '%s' "$commit_err" | grep -iE 'invalid option|unrecognized option|illegal option|usage: *grep' | head -1)"
	else
		ok "$label"
	fi
}

printf '\n%spre-commit guard — test suite%s\n' "$c_dim" "$c_off"

# ===========================================================================
printf '\nContent scan (positive controls)\n'
# ===========================================================================

r="$(new_repo)"
printf 'onboarding notes for ACME_CORP, renewal in Q3\n' > "$r/notes.md"
git -C "$r" add notes.md
attempt_commit "$r"
expect_block  "content: marker in a staged file is blocked"
expect_reason "content: ...and reported as a personal marker" "Personal markers found"

r="$(new_repo)"
mkdir -p "$r/PROJECT_ZEPHYR"
printf 'nothing sensitive in here\n' > "$r/PROJECT_ZEPHYR/readme.md"
git -C "$r" add PROJECT_ZEPHYR/readme.md
attempt_commit "$r"
expect_block  "content: marker in a staged file path is blocked"
expect_reason "content: ...and reported as a path hit" "path: PROJECT_ZEPHYR/readme.md"

# ===========================================================================
printf '\nCredential scan (positive controls)\n'
# ===========================================================================

# Assembled at runtime; the literals never appear in this file.
pem_header="-----BEGIN ""RSA PRIVATE KEY-----"
aws_key="AKI""AIOSFODNN7EXAMPLE"

r="$(new_repo)"
{ printf '%s\n' "$pem_header"
  printf 'MIIEowIBAAKCAQEAxFAKEfakeFAKEnotARealKeyAtAllJustPadding0123456789\n'
  printf -- '-----END ''RSA PRIVATE KEY-----\n'; } > "$r/id_rsa"
git -C "$r" add id_rsa
attempt_commit "$r"
expect_block                 "credential: PEM private key header is blocked"
expect_reason                "credential: ...and reported as credential-shaped" "Credential-shaped"
expect_no_grep_option_error  "credential: grep did not parse '-----BEGIN' as a flag"

r="$(new_repo)"
printf 'aws_access_key_id = %s\n' "$aws_key" > "$r/config.ini"
git -C "$r" add config.ini
attempt_commit "$r"
expect_block                 "credential: AWS access key id is blocked"
expect_reason                "credential: ...and reported as credential-shaped" "Credential-shaped"
expect_no_grep_option_error  "credential: no option error on the later alternatives"

# ===========================================================================
printf '\nCommit identity (positive controls)\n'
# ===========================================================================

r="$(new_repo)"
git -C "$r" config user.email "private@example.invalid"
printf 'clean content\n' > "$r/ok.md"
git -C "$r" add ok.md
attempt_commit "$r"
expect_block  "metadata: user.email containing a marker is blocked"
expect_reason "metadata: ...and reported as a guarded identity" "Commit identity contains a guarded marker"

r="$(new_repo)"
git -C "$r" config user.name "ACME_CORP Consulting"
printf 'clean content\n' > "$r/ok.md"
git -C "$r" add ok.md
attempt_commit "$r"
expect_block  "metadata: user.name containing a marker is blocked"
expect_reason "metadata: ...and reported as a guarded identity" "Commit identity contains a guarded marker"

r="$(new_repo)"
git -C "$r" config user.email "private@example.invalid"
attempt_commit "$r" --allow-empty
expect_block  "metadata: checked even when nothing is staged (--allow-empty)"
expect_reason "metadata: ...an empty commit still records an author line" "Commit identity contains a guarded marker"

# ===========================================================================
printf '\nMarker list protection (positive control)\n'
# ===========================================================================

r="$(new_repo)"
git -C "$r" add -f .personal-markers
attempt_commit "$r"
expect_block  "marker list: staging .personal-markers is blocked"
expect_reason "marker list: ...and named explicitly" ".personal-markers is staged"

# ===========================================================================
printf '\nIdentity allowlist\n'
# ===========================================================================

allowlisted_markers() {
	cat > "$1/.personal-markers" <<'EOF'
ACME_CORP
PUBLIC_ATTRIBUTION

[identity-allow]
PUBLIC_ATTRIBUTION
EOF
}

r="$(new_repo)"
allowlisted_markers "$r"
git -C "$r" config user.name "PUBLIC_ATTRIBUTION"
printf 'clean content\n' > "$r/ok.md"
git -C "$r" add ok.md
attempt_commit "$r"
expect_allow "allowlist: [identity-allow] permits a marker as the author name"

r="$(new_repo)"
allowlisted_markers "$r"
git -C "$r" config user.name "PUBLIC_ATTRIBUTION"
printf 'signed off by PUBLIC_ATTRIBUTION\n' > "$r/notes.md"
git -C "$r" add notes.md
attempt_commit "$r"
expect_block  "allowlist: scoped to identity — same string still blocked in content"
expect_reason "allowlist: ...and reported as a personal marker" "Personal markers found"

r="$(new_repo)"
allowlisted_markers "$r"
git -C "$r" config user.name "PUBLIC_ATTRIBUTION and ACME_CORP"
printf 'clean content\n' > "$r/ok.md"
git -C "$r" add ok.md
attempt_commit "$r"
expect_block "allowlist: exact match only — does not vouch for a superstring"

# ===========================================================================
printf '\nNegative controls (guard must stay out of the way)\n'
# ===========================================================================

r="$(new_repo)"
printf 'ordinary documentation, no markers, no keys\n' > "$r/ok.md"
git -C "$r" add ok.md
attempt_commit "$r"
expect_allow "clean: clean content and clean identity commits"

r="$(new_repo)"
rm -f "$r/.personal-markers"
printf 'ordinary documentation\n' > "$r/ok.md"
git -C "$r" add ok.md
attempt_commit "$r"
expect_allow  "no marker list: commit proceeds"
expect_reason "no marker list: ...with a warning that the scan was skipped" ".personal-markers not found"

# ===========================================================================
printf '\n%scommit-msg guard — test suite%s\n' "$c_dim" "$c_off"
# ===========================================================================
#
# Same discipline as above: every rejection asserts WHICH check fired, and the
# accept rows carry equal weight — a hook that rejects everything passes any
# suite made only of reject cases.

msg_hook="$here/../commit-msg"
[ -x "$msg_hook" ] || { printf 'no executable commit-msg at %s\n' "$msg_hook" >&2; exit 1; }

# A throwaway repo with only commit-msg installed, so the personal-marker guard
# cannot be what blocks a case here.
#
# The branch matters: the hook reads the team key off it, so the branch name is an
# input to every case below, not scenery. Defaults to a keyed branch (STRICT mode).
new_msg_repo() {
	local d branch="${1:-lev-276-fixture}"
	d="$(mktemp -d)"
	tmpdirs+=("$d")
	git -c init.defaultBranch=main init -q "$d"
	mkdir -p "$d/.githooks"
	cp "$msg_hook" "$d/.githooks/commit-msg"
	chmod +x "$d/.githooks/commit-msg"
	git -C "$d" config core.hooksPath .githooks
	git -C "$d" config commit.gpgsign false
	git -C "$d" config user.name "Clean Committer"
	git -C "$d" config user.email "1+clean@users.noreply.github.com"
	[ "$branch" = main ] || git -C "$d" checkout -q -b "$branch"
	printf 'seed\n' > "$d/file.txt"
	git -C "$d" add file.txt
	printf '%s' "$d"
}

# Commit with a given subject, capturing the same three facts as attempt_commit.
attempt_subject() {
	local d="$1" subject="$2"
	commit_err="$(git -C "$d" commit -m "$subject" 2>&1 >/dev/null)"
	commit_rc=$?
	commit_count="$(git -C "$d" rev-list --count --all 2>/dev/null || printf 'ERR')"
}

msg_block() { # subject, label, reason-needle, [branch]
	local d; d="$(new_msg_repo "${4:-}")"
	attempt_subject "$d" "$1"
	expect_block "$2"
	expect_reason "$2 — for the right reason" "$3"
}

msg_allow() { # subject, label, [branch]
	local d; d="$(new_msg_repo "${3:-}")"
	attempt_subject "$d" "$1"
	expect_allow "$2"
}

msg_block 'add a typing indicator' \
	'rejects: no type, no scope, no id' 'Not a Conventional Commit'
msg_block 'feat: add a typing indicator (LEV-231)' \
	'rejects: type but no scope' 'Not a Conventional Commit'
msg_block 'wip(skills): add a thing (LEV-231)' \
	'rejects: type outside the allowed set' 'Not a Conventional Commit'
msg_block 'feat(skills): add a typing indicator' \
	'rejects: no ticket id' 'does not end with a ticket id'
msg_block 'feat(skills): add a typing indicator (LEV-1..2)' \
	'rejects: ticket RANGE, not a list' 'Ticket ranges do not link'
msg_block 'feat(LEV-149): add a typing indicator' \
	'rejects: id in the scope slot' 'Not a Conventional Commit'

msg_allow 'feat(skills): add a typing indicator (LEV-231)' \
	'accepts: one id'
msg_allow 'fix(hooks): stop the early exit (LEV-230, LEV-231)' \
	'accepts: several ids, comma-separated'
msg_allow 'chore(hooks)!: drop the old entrypoint (LEV-231)' \
	'accepts: breaking-change marker'
msg_allow 'Merge branch feature into main' \
	'accepts: merge subject (git writes these)'
msg_allow 'Revert "feat(skills): add a typing indicator (LEV-231)"' \
	'accepts: revert subject'
msg_allow 'fixup! feat(skills): add a typing indicator (LEV-231)' \
	'accepts: fixup! (squashed away before it lands)'

# ---------------------------------------------------------------------------
# The team key is read off the branch, never hard-coded. These cases are the
# reason: a second team in the tracker must work with no edit to this file, and
# a key that does not belong to the branch must not pass.
# ---------------------------------------------------------------------------

msg_allow 'feat(skills): add a thing (OPS-42)' \
	'key: a DIFFERENT team key passes on its own branch' 'ops-42-runbook'
msg_block 'feat(skills): add a thing (LEV-42)' \
	'key: the wrong key is refused even though it is well-formed' 'Wrong team key' 'ops-42-runbook'
msg_block 'feat(skills): add a thing (ABC-1)' \
	'key: an invented key is refused on a keyed branch' 'Wrong team key' 'lev-276-fixture'
msg_block 'feat(skills): add a thing (LEV-230, ABC-1)' \
	'key: one bad key among several is still refused' 'Wrong team key' 'lev-276-fixture'
msg_allow 'feat(skills): add a thing (LEV-13)' \
	'key: legacy feat/KEY-nn branch shape still yields a key' 'feat/LEV-13-domain-models'

# A branch that merely looks keyed must not be mistaken for one — `v2-1-0` would
# read as key V2 if digits were allowed, hard-blocking every commit on it.
msg_allow 'feat(skills): add a thing (LEV-1)' \
	'key: v2-1-0 is not a team key — falls back, does not hard-block' 'v2-1-0'
msg_allow 'feat(skills): add a thing (LEV-1)' \
	'key: release-2-0 likewise' 'release-2-0'

# A keyed branch missing its id must name the key it expected, so the fix is
# obvious from the message alone.
msg_block 'feat(skills): add a thing' \
	'key: a missing id on a keyed branch names the expected key' 'expected LEV-<number>' 'lev-276-fixture'
msg_block 'feat(skills): add a thing' \
	'key: ...and the key it names comes from that branch' 'expected OPS-<number>' 'ops-42-runbook'

# On an unkeyed branch the key cannot be verified, so any well-formed one passes.
# (The "no id at all" case on such a branch is the public-repo behaviour below —
# the sibling private copy refuses it instead, which is the one line they differ by.)
msg_allow 'feat(skills): add a thing (ABC-1)' \
	'key: unkeyed branch accepts any well-formed key' 'main'

# ---------------------------------------------------------------------------
# Outside contributors. This repository is public: someone sending a pull request
# from their own fork has no ticket number and must not be asked to invent one.
# This is the single behavioural difference from the private siblings' copy.
# ---------------------------------------------------------------------------

msg_allow 'docs(readme): fix a typo' \
	'public: no ticket id needed on a branch the contributor named' 'fix-readme-typo'
msg_allow 'feat(skills): add a thing' \
	'public: ...same on any unkeyed branch' 'my-cool-feature'
msg_block 'add a thing' \
	'public: but Conventional Commits shape is still required' 'Not a Conventional Commit' 'my-cool-feature'
msg_block 'docs(readme): fix a typo' \
	'public: a maintainer on a keyed branch is still bound' 'ticket id' 'lev-276-fixture'

# ===========================================================================
printf '\n%spre-push guard — test suite%s\n' "$c_dim" "$c_off"
# ===========================================================================
#
# THE TRAP THIS SUITE EXISTS TO AVOID. git hands pre-push an EMPTY stdin when
# there is nothing to send, so the hook's read loop never runs and it exits 0.
# A push attempted from an up-to-date branch therefore "passes" while proving
# nothing whatsoever about the guard. Every case below pushes a real commit the
# remote does not have, and the first case pins the trap itself so nobody later
# mistakes that green for a working guard.

push_hook="$here/../pre-push"
[ -x "$push_hook" ] || { printf 'no executable pre-push at %s\n' "$push_hook" >&2; exit 1; }

push_err=''
push_rc=0

# A clone with pre-push installed and a bare remote to push at. Echoes the path.
new_push_repo() {
	local d remote
	d="$(mktemp -d)"; remote="$(mktemp -d)"
	tmpdirs+=("$d" "$remote")
	git -c init.defaultBranch=main init -q --bare "$remote"
	git -c init.defaultBranch=main init -q "$d"
	git -C "$d" config commit.gpgsign false
	git -C "$d" config user.name "Clean Committer"
	git -C "$d" config user.email "1+clean@users.noreply.github.com"
	git -C "$d" remote add origin "$remote"
	printf 'seed\n' > "$d/file.txt"
	git -C "$d" add file.txt
	git -C "$d" commit -q -m 'chore(hooks): seed (LEV-1)' --no-verify
	git -C "$d" push -q origin main
	# Installed only now, so the seed push above is not what we are measuring.
	mkdir -p "$d/.githooks"
	cp "$push_hook" "$d/.githooks/pre-push"
	chmod +x "$d/.githooks/pre-push"
	git -C "$d" config core.hooksPath .githooks
	printf '%s' "$d"
}

attempt_push() { # dir, [env assignments...]
	local d="$1"; shift
	push_err="$(env "$@" git -C "$d" push origin HEAD:refs/heads/main 2>&1 >/dev/null)"
	push_rc=$?
}

# Case 0 — the trap, pinned. Nothing to push, so the hook is never consulted.
r="$(new_push_repo)"
attempt_push "$r"
if [ "$push_rc" -eq 0 ]; then
	ok "TRAP: an up-to-date push exits 0 without the hook firing (this is why the cases below diverge first)"
else
	bad "TRAP: an up-to-date push exits 0 without the hook firing" \
		"expected rc=0 from a no-op push, got rc=$push_rc — the trap this suite documents may have changed"
fi

# Case 1 — a real divergence. Now the hook has something to read.
r="$(new_push_repo)"
git -C "$r" commit -q --allow-empty -m 'chore(hooks): diverge (LEV-1)' --no-verify
attempt_push "$r"
if [ "$push_rc" -eq 0 ]; then
	bad "blocks a direct push to main" "guard did not fire: push succeeded (rc=0)"
else
	case "$push_err" in
		*'Refusing to push directly to'*) ok "blocks a direct push to main" ;;
		*) bad "blocks a direct push to main" \
			"rejected (rc=$push_rc) but not by this hook: $(printf '%s' "$push_err" | tr '\n' ' ' | cut -c1-160)" ;;
	esac
fi
remote_after="$(git -C "$r" ls-remote origin refs/heads/main | cut -f1)"
local_head="$(git -C "$r" rev-parse HEAD)"
if [ "$remote_after" != "$local_head" ]; then
	ok "blocked push left the remote branch untouched"
else
	bad "blocked push left the remote branch untouched" "remote main moved to $local_head anyway"
fi

# Case 2 — the escape hatch. A guard whose override is broken gets disabled.
r="$(new_push_repo)"
git -C "$r" commit -q --allow-empty -m 'chore(hooks): diverge (LEV-1)' --no-verify
attempt_push "$r" ALLOW_PROTECTED_PUSH=1
if [ "$push_rc" -eq 0 ]; then
	ok "ALLOW_PROTECTED_PUSH=1 permits the same push"
else
	bad "ALLOW_PROTECTED_PUSH=1 permits the same push" \
		"override failed (rc=$push_rc): $(printf '%s' "$push_err" | tr '\n' ' ' | cut -c1-160)"
fi

# Case 3 — deletion of a protected branch is a push too.
r="$(new_push_repo)"
push_err="$(git -C "$r" push origin --delete main 2>&1 >/dev/null)"
push_rc=$?
case "$push_err" in
	*'Refusing to push directly to'*) ok "blocks deletion of a protected branch" ;;
	*) bad "blocks deletion of a protected branch" \
		"rc=$push_rc, stderr: $(printf '%s' "$push_err" | tr '\n' ' ' | cut -c1-160)" ;;
esac

# Case 4 — negative control: an ordinary feature branch is none of the hook's business.
r="$(new_push_repo)"
git -C "$r" checkout -q -b lev-1-feature
git -C "$r" commit -q --allow-empty -m 'chore(hooks): work (LEV-1)' --no-verify
push_err="$(git -C "$r" push origin HEAD:refs/heads/lev-1-feature 2>&1 >/dev/null)"
push_rc=$?
if [ "$push_rc" -eq 0 ]; then
	ok "lets an ordinary branch through"
else
	bad "lets an ordinary branch through" \
		"false positive (rc=$push_rc): $(printf '%s' "$push_err" | tr '\n' ' ' | cut -c1-160)"
fi

# ===========================================================================
printf '\n%s──────────────────────────────────────────────%s\n' "$c_dim" "$c_off"
if [ "$n_fail" -eq 0 ]; then
	printf '%s%d passed%s, 0 failed\n\n' "$c_green" "$n_pass" "$c_off"
	exit 0
fi
printf '%d passed, %s%d failed%s\n\n' "$n_pass" "$c_red" "$n_fail" "$c_off"
exit 1
