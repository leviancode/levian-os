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
printf '\n%s──────────────────────────────────────────────%s\n' "$c_dim" "$c_off"
if [ "$n_fail" -eq 0 ]; then
	printf '%s%d passed%s, 0 failed\n\n' "$c_green" "$n_pass" "$c_off"
	exit 0
fi
printf '%d passed, %s%d failed%s\n\n' "$n_pass" "$c_red" "$n_fail" "$c_off"
exit 1
