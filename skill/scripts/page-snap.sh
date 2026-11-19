#!/bin/bash
# Token-cheap page snapshot of a tab chosen by URL, for headed background mode (where the
# session's current tab is about:blank). Full snapshots of heavy pages cost 8k to 20k tokens;
# start with a shallow overview, then expand only the block you need.
# Usage: page-snap.sh [-s SESSION] URL_PART [--depth N] [--ref eN] [--grep REGEX] [--interactive] [--max CHARS]
#   URL_PART       substring of the tab URL (chatgpt.com, gemini.google, flow.google)
#   --depth N      limit tree depth (default 4 for a page overview; unlimited with --ref,
#                  --grep or --interactive, which return only their own lines)
#   --ref eN       snapshot only that element's subtree (ref from a previous snapshot)
#   --grep REGEX   keep only matching lines (case-insensitive), for example "button|textbox"
#   --interactive  keep only buttons, links, inputs and similar controls
#   --max CHARS    cut the output (default 8000) and say so
# Refs in the output work with: p.locator('aria-ref=eN').click() inside run-code.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; . "$here/_lib.sh"
SESSION="${PLAYWRIGHT_CLI_SESSION:-web}"; URLP=""; DEPTH=""; REF=""; GREP=""; INTER=0; MAX=8000
while [ $# -gt 0 ]; do case "$1" in
  -s) SESSION="$2"; shift 2;; -s=*) SESSION="${1#-s=}"; shift;;
  --depth) DEPTH="$2"; shift 2;; --ref) REF="$2"; shift 2;; --grep) GREP="$2"; shift 2;;
  --interactive) INTER=1; shift;; --max) MAX="$2"; shift 2;;
  -h|--help) sed -n '2,14p' "$0"; exit 0;; *) URLP="$1"; shift;; esac; done
[ -n "$URLP" ] || { sed -n '2,14p' "$0"; exit 1; }
[ -n "$DEPTH" ] || { [ -n "$REF$GREP" ] || [ "$INTER" = 1 ] && DEPTH=0 || DEPTH=4; }
args="$(python3 -c 'import json,sys; print(json.dumps({"u":sys.argv[1],"d":int(sys.argv[2]),"r":sys.argv[3],"g":sys.argv[4],"i":sys.argv[5]=="1","m":int(sys.argv[6])}))' "$URLP" "$DEPTH" "$REF" "$GREP" "$INTER" "$MAX")"
run_js "$SESSION" <<JS
async page => {
  const a = $args;
  const p = page.context().pages().find(p => p.url().includes(a.u));
  if (!p) return 'no tab with "' + a.u + '"; tabs: ' + page.context().pages().map(p => p.url()).join(' | ');
  const opts = { mode: 'ai' }; if (a.d > 0) opts.depth = a.d;
  const target = a.r ? p.locator('aria-ref=' + a.r) : p.locator('body');
  let s = a.r ? await target.ariaSnapshot(opts) : await p.ariaSnapshot(opts);
  let lines = s.split('\n');
  if (a.i) lines = lines.filter(l => /\[ref=e\d+\]/.test(l) && /^\s*- (button|link|textbox|searchbox|combobox|checkbox|radio|switch|menuitem|tab|option|slider)\b/.test(l)).map(l => l.trim());
  if (a.g) { const re = new RegExp(a.g, 'i'); lines = lines.filter(l => re.test(l)); }
  s = lines.join('\n');
  const head = '# ' + p.url() + ' | ' + (await p.title()) + (a.d > 0 ? ' | depth ' + a.d : '') + '\n';
  return head + (s.length > a.m ? s.slice(0, a.m) + '\n... cut at ' + a.m + ' of ' + s.length + ' chars: use --ref, --grep or --interactive' : s);
}
JS
