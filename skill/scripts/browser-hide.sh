#!/bin/bash
# Put the session's browser out of the way again: minimize all its windows and, if Chrome is the
# frontmost app, hide it so macOS gives focus back to the app the user was in. Use after a manual
# sign-in, or if a window ever pops up.
# Usage: browser-hide.sh [-s SESSION]
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/_lib.sh"
SESSION="${PLAYWRIGHT_CLI_SESSION:-web}"
case "${1:-}" in -s) SESSION="$2";; -s=*) SESSION="${1#-s=}";; -h|--help) sed -n '2,5p' "$0"; exit 0;; esac
n="$(minimize_all "$SESSION")" || exit 1
fp="$(front_pid)"
if [ "$(pid_name "$fp")" = "Google Chrome" ]; then hide_pid "$fp"; fi
echo "minimized $n window(s); frontmost now: $(pid_name "$(front_pid)")"
