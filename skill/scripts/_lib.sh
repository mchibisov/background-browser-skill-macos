# Shared helpers for the browser skill scripts (sourced, not run).
command -v playwright-cli >/dev/null 2>&1 || { export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh" >/dev/null 2>&1; }
command -v playwright-cli >/dev/null 2>&1 || { echo "playwright-cli not found" >&2; exit 1; }

# Run a Playwright function (file content on stdin) in a session; print its result value.
run_js() {  # run_js SESSION < code.js
  local d f; d="$(mktemp -d -t pwjs)"; f="$d/code.js"; cat > "$f"
  local out; out="$(playwright-cli -s="$1" run-code --filename="$f" 2>&1)"; rm -f "$f"; rmdir "$d"
  printf '%s\n' "$out" | python3 -c '
import json, sys
lines = sys.stdin.read().splitlines()
if "### Result" in lines:
    v = lines[lines.index("### Result") + 1]
    try: v = json.loads(v)
    except Exception: pass
    print(v); sys.exit(0)
print("\n".join(l for l in lines if l.strip())[:2000], file=sys.stderr); sys.exit(1)'
}

# macOS app focus helpers (AppKit via JXA, no Accessibility permission needed).
# On other systems they do nothing: CDP minimize and background tabs still work there,
# but focus restore after launch is macOS-only and untested elsewhere.
if [ "$(uname -s)" != Darwin ]; then
  front_pid() { :; }; pid_name() { :; }; activate_pid() { :; }; hide_pid() { :; }
else
front_pid() { osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier' 2>/dev/null; }
pid_name() { ps -o comm= -p "$1" 2>/dev/null | sed 's#.*/##'; }
activate_pid() { osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationWithProcessIdentifier($1).activateWithOptions(\$.NSApplicationActivateIgnoringOtherApps)" >/dev/null 2>&1; }
hide_pid() { osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSRunningApplication.runningApplicationWithProcessIdentifier($1).hide" >/dev/null 2>&1; }
fi

# Minimize every window of the session's browser via CDP; print how many.
minimize_all() {
  run_js "$1" <<'JS'
async page => {
  const ctx = page.context(); const seen = new Set();
  for (const p of ctx.pages()) {
    const s = await ctx.newCDPSession(p);
    try {
      const { windowId, bounds } = await s.send('Browser.getWindowForTarget');
      if (!seen.has(windowId)) {
        seen.add(windowId);
        if (bounds.windowState === 'fullscreen' || bounds.windowState === 'maximized')
          await s.send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'normal' } });
        await s.send('Browser.setWindowBounds', { windowId, bounds: { windowState: 'minimized' } });
      }
    } finally { await s.detach(); }
  }
  return seen.size;
}
JS
}

# Open URLs as background tabs (no focus change); skip a URL whose host already has a tab.
bg_tabs() {  # bg_tabs SESSION URL...
  local session="$1"; shift
  [ $# -gt 0 ] || return 0
  local urls; urls="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$@")"
  run_js "$session" <<JS
async page => {
  const ctx = page.context(); const urls = $urls; const out = [];
  const s = await ctx.newCDPSession(page);
  const { targetInfo } = await s.send('Target.getTargetInfo');
  for (const url of urls) {
    const host = new URL(url).host;
    const have = ctx.pages().findIndex(p => { try { return new URL(p.url()).host === host; } catch { return false; } });
    if (have >= 0) { out.push(have + ' ' + ctx.pages()[have].url() + ' (existing)'); continue; }
    const created = ctx.waitForEvent('page', { timeout: 20000 });
    await s.send('Target.createTarget', { url, background: true, browserContextId: targetInfo.browserContextId });
    const p = await created;
    out.push(ctx.pages().indexOf(p) + ' ' + url + ' (new, background)');
  }
  await s.detach();
  return out.join('\n');
}
JS
}

# Make target=_blank links and window.open stay in the same tab, so sites cannot pop a new
# window or tab to the front. Applies to new documents and to the pages open right now.
install_guard() {
  run_js "$1" <<'JS'
async page => {
  const guard = () => {
    if (window.__pwNoPopup) return; window.__pwNoPopup = true;
    window.open = (u) => { if (u) location.href = new URL(u, location.href).href; return window; };
    document.addEventListener('click', e => {
      const a = e.target && e.target.closest && e.target.closest('a[target]');
      if (a && a.target !== '_self') a.target = '_self';
    }, true);
  };
  const ctx = page.context();
  if (!ctx.__pwNoPopup) { await ctx.addInitScript(guard); ctx.__pwNoPopup = true; }
  for (const p of ctx.pages()) await p.evaluate(guard).catch(() => {});
  return 'guard on ' + ctx.pages().length + ' tabs';
}
JS
}
