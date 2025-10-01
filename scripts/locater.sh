#!/usr/bin/env bash
set -euo pipefail

# A simple rofi script mode that uses `locate` to find files by name.
# - On initial/incremental calls (ROFI_RETV=0) it reads ROFI_INPUT and prints
#   matching file paths. The displayed text is the basename while the full
#   path is stored in the 'info' field so we can open it on selection.
# - When an entry is selected (ROFI_RETV=1) the script opens the file with
#   xdg-open (or a sensible fallback) in the background and exits.

null=$'\0'
sep=$'\x1f'

ROFI_RETV=${ROFI_RETV:-0}
QUERY=${ROFI_INPUT:-}

open_target() {
    target="$1"
    # Ensure we have something to open
    [ -n "$target" ] || return 0

    # Prefer xdg-open, then gio, then mimeopen. Launch in background so rofi
    # doesn't wait for the opener to finish.
    if command -v xdg-open >/dev/null 2>&1; then
        setsid xdg-open "$target" >/dev/null 2>&1 &
    elif command -v gio >/dev/null 2>&1; then
        setsid gio open "$target" >/dev/null 2>&1 &
    elif command -v mimeopen >/dev/null 2>&1; then
        setsid mimeopen -n "$target" >/dev/null 2>&1 &
    else
        # Last resort: try to open with $TERMINAL (if set) and an editor
        if [ -n "${TERMINAL:-}" ] && command -v ${TERMINAL%% *} >/dev/null 2>&1; then
            # open a terminal in the file's directory and open with $EDITOR or vi
            editor=${EDITOR:-vi}
            dir=$(dirname -- "$target")
            base=$(basename -- "$target")
            setsid ${TERMINAL%% *} -e sh -c "cd \"$dir\" && $editor \"$base\"" >/dev/null 2>&1 &
        fi
    fi
}

if [ "$ROFI_RETV" -eq 1 ] || [ "$#" -gt 0 ]; then
    # Selection case. Prefer ROFI_INFO (set via 'info' row option). If not set
    # fall back to the first script argument.
    sel="${ROFI_INFO:-${1:-}}"
    open_target "$sel"
    exit 0
fi

# Initial/incremental call: produce entries. Must always print at least one
# non-empty row otherwise rofi will quit.
if [ -z "$QUERY" ]; then
    # Help row (nonselectable)
    printf 'Type to search with locate%snonselectable%strue\n' "$null" "$sep"
    exit 0
fi

if ! command -v locate >/dev/null 2>&1; then
    printf 'locate not found%snonselectable%strue\n' "$null" "$sep"
    exit 0
fi

# Run locate. Try a simple case-insensitive substring search. Fall back to
# plain locate if the -i option isn't supported on some implementations.
results=$(locate -i -- "$QUERY" 2>/dev/null || locate -- "$QUERY" 2>/dev/null || true)

if [ -z "$results" ]; then
    printf 'No results for: %s%snonselectable%strue\n' "$QUERY" "$null" "$sep"
    exit 0
fi

# Remove duplicates and limit results to a reasonable number
printf '%s\n' "$results" | awk '!seen[$0]++' | head -n 200 | while IFS= read -r path; do
    # present the basename as the displayed string, keep full path in info
    base=$(basename -- "$path")
    # Format: entry<\0>display<US><display-string><US>info<US><info-value>\n
    printf '%s\n' "${path}${null}display${sep}${base}${sep}info${sep}${path}"
done
