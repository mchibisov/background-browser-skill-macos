#!/bin/bash
# Open URLs as background tabs in a running playwright-cli browser without focusing or
# un-minimizing it (CDP Target.createTarget background:true). Prints "<index> <url>".
# Never use `playwright-cli tab-new` / `tab-select` in a headed browser: they bring Chrome to the front.
# Usage: bg-tab.sh [-s SESSION] URL...
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/_lib.sh"
SESSION="${PLAYWRIGHT_CLI_SESSION:-web}"
case "${1:-}" in -s) SESSION="$2"; shift 2;; -s=*) SESSION="${1#-s=}"; shift;; -h|--help|"") sed -n '2,5p' "$0"; exit 0;; esac
bg_tabs "$SESSION" "$@"
