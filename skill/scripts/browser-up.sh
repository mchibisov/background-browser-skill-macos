#!/bin/bash
# Start or reuse a headed Google Chrome for playwright-cli that stays minimized and never takes
# the user's focus, then open URLs as background tabs (a URL whose host already has a tab is reused).
# Usage: browser-up.sh [-s SESSION] [--profile DIR] [--headless] [URL...]
#   -s SESSION   playwright-cli session to use (default: $PLAYWRIGHT_CLI_SESSION or "web").
#                If a browser with this profile is already running under another session or
#                workspace, SESSION is attached to it instead of starting a second browser.
#   --profile    user data dir (default: ~/playwright-profiles/default)
#   --headless   start headless instead (no window at all; sites behind Cloudflare may block it)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/_lib.sh"
SESSION="${PLAYWRIGHT_CLI_SESSION:-web}"; PROFILE="$HOME/playwright-profiles/default"; HEADLESS=0; URLS=()
while [ $# -gt 0 ]; do case "$1" in
  -s) SESSION="$2"; shift 2;; -s=*) SESSION="${1#-s=}"; shift;;
  --profile) PROFILE="$2"; shift 2;; --profile=*) PROFILE="${1#--profile=}"; shift;;
  --headless) HEADLESS=1; shift;; -h|--help) sed -n '2,10p' "$0"; exit 0;;
  *) URLS+=("$1"); shift;; esac; done
PROFILE="$(cd "$PROFILE" 2>/dev/null && pwd || echo "$PROFILE")"

state="$( { playwright-cli list --json 2>/dev/null; echo; echo "#ALL#"; playwright-cli list --all --json 2>/dev/null; } | python3 -c '
import json, sys
session, profile = sys.argv[1], sys.argv[2]
here, _, every = sys.stdin.read().partition("#ALL#")
def load(s):
    try: return json.loads(s)
    except Exception: return {}
# Reuse only a session of this workspace (git root or cwd): same-named sessions elsewhere are not ours.
for b in load(here).get("browsers", []):
    if b.get("name") == session and b.get("status") == "open":
        print("reuse"); sys.exit()
for s in load(every).get("servers", []):
    if (s.get("browser") or {}).get("userDataDir") == profile:
        print("attach " + s["title"]); sys.exit()
print("open")' "$SESSION" "$PROFILE")"

case "$state" in
  reuse) echo "session $SESSION: reusing the running browser";;
  attach*)
    owner="${state#attach }"
    playwright-cli attach "$owner" --session="$SESSION" >/dev/null 2>&1 \
      || { echo "attach to $owner failed" >&2; exit 1; }
    echo "session $SESSION: attached to running browser \"$owner\" (no new window)";;
  open)
    mkdir -p "$PROFILE"
    if [ "$HEADLESS" = 1 ]; then
      playwright-cli -s="$SESSION" open --profile="$PROFILE" about:blank >/dev/null 2>&1 || { echo "open failed" >&2; exit 1; }
      echo "session $SESSION: started headless"
    else
      fp="$(front_pid)"
      playwright-cli -s="$SESSION" open --headed --profile="$PROFILE" about:blank >/dev/null 2>&1 || { echo "open failed (profile in use by a browser outside playwright-cli?)" >&2; exit 1; }
      minimize_all "$SESSION" >/dev/null
      if [ -n "$fp" ] && [ "$(pid_name "$fp")" != "Google Chrome" ]; then activate_pid "$fp"; fi
      echo "session $SESSION: started headed, minimized, focus returned to $(pid_name "$fp")"
    fi;;
esac

install_guard "$SESSION" >/dev/null || echo "warning: popup guard not installed" >&2
[ ${#URLS[@]} -gt 0 ] && bg_tabs "$SESSION" "${URLS[@]}"
echo "tabs:"; playwright-cli -s="$SESSION" tab-list 2>/dev/null | grep -E '^- ' | sed 's/(current) //'
