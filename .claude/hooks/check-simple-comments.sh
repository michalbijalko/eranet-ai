#!/usr/bin/env bash
# Stop hook: flag verbose (multi-line) comment blocks added in the working diff.
# VSE rule: keep code comments to one line. Self-clearing — once simplified or
# committed, the diff is clean and this passes.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
repos=("publicERANET-server" "publicERANET-client")
flagged=""

# Only flag runs of inline // line comments; structured /* */ and /** */ Javadoc is left alone.
is_comment_line() {
	local l="$1"
	l="${l#"${l%%[![:space:]]*}"}" # strip leading whitespace
	case "$l" in
		//*) return 0 ;;
		*) return 1 ;;
	esac
}

for r in "${repos[@]}"; do
	dir="$PROJECT_DIR/$r"
	[ -d "$dir" ] || continue
	diff="$(git -C "$dir" diff -- '*.java' '*.js' 2>/dev/null; git -C "$dir" diff --cached -- '*.java' '*.js' 2>/dev/null)"
	[ -n "$diff" ] || continue

	run=0
	file=""
	while IFS= read -r line; do
		case "$line" in
			"diff --git"*) file="${line##* b/}"; run=0 ;;
			"+++"*|"---"*|"@@"*) run=0 ;;
			"+"*)
				if is_comment_line "${line:1}"; then
					run=$((run + 1))
					[ "$run" -ge 2 ] && flagged="${flagged}${r}/${file}"$'\n'
				else
					run=0
				fi
				;;
			*) run=0 ;;
		esac
	done <<< "$diff"
done

flagged="$(printf '%s' "$flagged" | sort -u | sed '/^$/d')"

if [ -n "$flagged" ]; then
	{
		echo "Verbose multi-line comment block(s) were added. VSE rule: keep code comments to one line."
		echo "Simplify them (or run the comment-simplifier agent on the diff). Files:"
		printf '%s\n' "$flagged" | sed 's/^/  - /'
	} >&2
	exit 2
fi
exit 0
