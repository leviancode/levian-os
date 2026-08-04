#!/usr/bin/env bash
#
# Append a dated entry to a project chronicle.
#
# This is the mechanical half of the `chronicle` skill — the half that must not
# be improvised: it creates the chronicle with its fixed header when absent,
# instantiates the template for the requested shape and appends it at the end.
# The prose is written afterwards, into the file whose path this prints.
#
#     append-entry.sh milestone "v1.4.0"
#     append-entry.sh narrative "2026-W31"
#     -> docs/HISTORY.md:42
#
# Nothing above the new entry is read or rewritten, so `git diff` on a correct
# run shows additions only. That is the property the skill's verify step checks.

set -euo pipefail

die() { printf 'append-entry: %s\n' "$*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage: append-entry.sh [--file FILE] [--date YYYY-MM-DD] <milestone|narrative> "<label>"

  --file  chronicle file (default: <repo root>/docs/HISTORY.md)
  --date  entry date (default: today)

  <label> the version for a milestone entry, the period for a narrative one.

Prints <path>:<line>, the line the new entry starts on.
EOF
}

shape=''
label=''
file=''
date=''

while [ $# -gt 0 ]; do
	case "$1" in
		--file) [ $# -ge 2 ] || die "--file needs a value"; file="$2"; shift 2 ;;
		--date) [ $# -ge 2 ] || die "--date needs a value"; date="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		--) shift; break ;;
		-*) die "unknown option: $1" ;;
		*)
			if [ -z "$shape" ]; then
				shape="$1"
			elif [ -z "$label" ]; then
				label="$1"
			else
				die "unexpected third argument: $1 (quote the label)"
			fi
			shift ;;
	esac
done

case "$shape" in
	milestone|narrative) ;;
	'') usage >&2; exit 2 ;;
	*) die "unknown shape: $shape (expected milestone or narrative)" ;;
esac
[ -n "$label" ] || { usage >&2; exit 2; }

# ── Where the chronicle lives ────────────────────────────────────────────────
if [ -z "$file" ]; then
	root="$(git rev-parse --show-toplevel 2>/dev/null)" \
		|| die "not inside a git repository — pass --file"
	file="$root/docs/HISTORY.md"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$script_dir/../template-$shape.md"
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

# ── The file, and its fixed header ───────────────────────────────────────────
# The header is written here rather than left to each project because it states
# the one rule the whole mechanism rests on: the file is compiled, never edited
# by hand. A header every repository retypes is a header that drifts, and this
# one has to mean the same thing everywhere for the claim to be worth anything.
if [ ! -e "$file" ]; then
	mkdir -p "$(dirname "$file")"
	cat > "$file" <<'EOF'
# History

Project chronicle. Compiled only — entries are appended by /ship (release milestones) and /retro (weekly narrative). Never edited by hand.
EOF
fi
[ -f "$file" ] || die "$file exists but is not a regular file"

# ── Instantiate ──────────────────────────────────────────────────────────────
# Bash substitution, not sed: a label may contain /, &, or a backslash.
body="$(cat "$template")"
body="${body//\{\{LABEL\}\}/$label}"
body="${body//\{\{DATE\}\}/$date}"

# ── Append at the end, and only at the end ───────────────────────────────────
# Close an unterminated last line first, then one blank line as the separator,
# so the entry lands the same way whether the file ends with the header, a
# previous entry, or no trailing newline at all.
if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
	printf '\n' >> "$file"
fi
printf '\n' >> "$file"

start=$(( $(wc -l < "$file") + 1 ))
printf '%s\n' "$body" >> "$file"

printf '%s:%s\n' "$file" "$start"
