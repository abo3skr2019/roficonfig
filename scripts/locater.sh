
#!/usr/bin/env bash
"${DEBUG:-:}" # no-op to allow set -u without failing in some shells
set -u

# Rofi script mode for locating files using `locate`.
#
# Behavior:
# - Initial call (ROFI_RETV=0): print a short hint and set the prompt.
# - Custom entry selected (ROFI_RETV=2): treat the typed text as a query,
#   run `locate` and print matching paths as rows. Each row contains the
#   actual path as the entry (used for filtering) but uses the `display`
#   option to show a nicer string (basename — fullpath). The `info` field
#   contains the full path and is used when opening the file.
# - Entry selected (ROFI_RETV=1): open the path stored in ROFI_INFO (or
#   the selected entry) with xdg-open in the background.

ROFI_RETV=${ROFI_RETV:-0}

case "$ROFI_RETV" in
	0)
		# Initial call: set prompt and show a short hint. Allow custom entries
		# (do not set no-custom=true) so the user can type a query and press Enter.
		echo -en "\0prompt\x1fLocate: \n"
		echo "Type a query and press Enter to search with locate"
		exit 0
		;;

	2)
		# Custom entry was entered (user typed a search and pressed Enter).
		query="${1:-}"
		# if query is empty, nothing to do
		if [ -z "$query" ]; then
			echo "No query provided"
			exit 0
		fi

		# Max number of results to show (tweakable)
		MAX_RESULTS=200

		# Run locate. Use case-insensitive search (-i) and limit results (-n).
		# Silence errors (database missing, permissions, etc.).
		# Note: different locate implementations accept these flags (mlocate/updatedb).
		mapfile -t results < <(locate -i -n "$MAX_RESULTS" "$query" 2>/dev/null || true)

		if [ "${#results[@]}" -eq 0 ]; then
			echo "No results for '$query'"
			exit 0
		fi

		for path in "${results[@]}"; do
			# Print each result as: original_entry<\0>display\x1f<nice>\x1finfo\x1f<path>\n
			# Use the full path as the original entry so filtering works on the full
			# path. Use display to show a friendlier line (basename — fullpath).
			base=$(basename -- "${path}")
			display="$base — $path"
			# printf handles special characters more robustly than echo
			printf '%s\0display\x1f%s\x1finfo\x1f%s\n' "$path" "$display" "$path"
		done
		exit 0
		;;

	1)
		# A listed entry was selected. Try to open it with xdg-open.
		target="${ROFI_INFO:-${1:-}}"
		if [ -z "$target" ]; then
			exit 0
		fi

		# Launch in background so rofi doesn't wait. Use setsid to detach.
		setsid xdg-open -- "$target" >/dev/null 2>&1 &
		exit 0
		;;

	*)
		# Unhandled Rofi return value: just exit quietly.
		exit 0
		;;
esac
