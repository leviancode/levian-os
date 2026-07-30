#!/usr/bin/env bash
#
# Allocate and instantiate an architecture decision record.
#
# This is the mechanical half of the `adr` skill — the half that must not be
# improvised: it picks the next number, derives the slug, instantiates
# template.md and appends the index line. The prose is written afterwards, into
# the file whose path this prints on stdout.
#
#     new-adr.sh "Session state in signed cookies, not server storage"
#     -> docs/decisions/004-session-state-in-signed-cookies-not-server-storage.md
#
# The records directory and its INDEX.md are created when absent, so the first
# record in a repository needs no setup.

set -euo pipefail

SLUG_MAX=60

die() { printf 'new-adr: %s\n' "$*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage: new-adr.sh [--dir DIR] [--date YYYY-MM-DD] "<decision title>"

  --dir   records directory (default: <repo root>/docs/decisions)
  --date  record date (default: today)

Prints the path of the created record.
EOF
}

title=''
dir=''
date=''

while [ $# -gt 0 ]; do
	case "$1" in
		--dir)  [ $# -ge 2 ] || die "--dir needs a value";  dir="$2";  shift 2 ;;
		--date) [ $# -ge 2 ] || die "--date needs a value"; date="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		--) shift; break ;;
		-*) die "unknown option: $1" ;;
		*)
			if [ -n "$title" ]; then
				die "unexpected second argument: $1 (quote the title)"
			fi
			title="$1"; shift ;;
	esac
done
if [ -z "$title" ] && [ $# -gt 0 ]; then title="$1"; fi

[ -n "$title" ] || { usage >&2; exit 2; }

# ── Where the records live ───────────────────────────────────────────────────
if [ -z "$dir" ]; then
	root="$(git rev-parse --show-toplevel 2>/dev/null)" \
		|| die "not inside a git repository — pass --dir"
	dir="$root/docs/decisions"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$script_dir/../template.md"
[ -f "$template" ] || die "template not found at $template"

# ── Date ─────────────────────────────────────────────────────────────────────
if [ -z "$date" ]; then
	date="$(date "+%Y-%m-%d")"
else
	case "$date" in
		[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
		*) die "--date must be YYYY-MM-DD" ;;
	esac
fi

# ── Slug ─────────────────────────────────────────────────────────────────────
slug="$(printf '%s' "$title" \
	| tr '[:upper:]' '[:lower:]' \
	| sed 's/[^a-z0-9]\{1,\}/-/g; s/^-*//; s/-*$//')"
[ -n "$slug" ] || die "title has no alphanumeric characters to build a slug from"

if [ "${#slug}" -gt "$SLUG_MAX" ]; then
	cut="${slug:0:$SLUG_MAX}"
	# Only trim back to the previous word when the cut landed mid-word.
	if [ "${slug:$SLUG_MAX:1}" != "-" ]; then
		cut="${cut%-*}"
	fi
	slug="${cut%-}"
	[ -n "$slug" ] || die "title truncates to an empty slug"
fi

# ── Number: highest existing + 1, never a count (gaps must not be reused) ────
mkdir -p "$dir"
next=1
for f in "$dir"/[0-9]*-*.md; do
	[ -e "$f" ] || continue
	base="${f##*/}"
	n="${base%%-*}"
	case "$n" in
		''|*[!0-9]*) continue ;;
	esac
	n=$((10#$n))
	if [ "$n" -ge "$next" ]; then
		next=$((n + 1))
	fi
done
printf -v number '%03d' "$next"

file="$dir/$number-$slug.md"
if [ -e "$file" ]; then
	die "$file already exists — refusing to overwrite"
fi

# ── Instantiate ──────────────────────────────────────────────────────────────
# Bash substitution, not sed: a title may contain /, &, or a backslash.
body="$(cat "$template")"
body="${body//\{\{NUMBER\}\}/$number}"
body="${body//\{\{TITLE\}\}/$title}"
body="${body//\{\{DATE\}\}/$date}"
printf '%s\n' "$body" > "$file"

# ── Index ────────────────────────────────────────────────────────────────────
index="$dir/INDEX.md"
if [ ! -e "$index" ]; then
	cat > "$index" <<'EOF'
# Architecture Decision Records

One file per decision. Newest last.
EOF
fi

# Append cleanly whether the index ends with the header, an entry, or no
# trailing newline at all.
if [ -s "$index" ] && [ -n "$(tail -c 1 "$index")" ]; then
	printf '\n' >> "$index"
fi
last="$(grep -v '^[[:space:]]*$' "$index" | tail -n 1 || true)"
case "$last" in
	'- '*) ;;
	*) printf '\n' >> "$index" ;;
esac
printf -- '- [%s](%s) · %s · %s\n' "$number" "$number-$slug.md" "$title" "$date" >> "$index"

printf '%s\n' "$file"
