#!/bin/bash
# Install the /browser skill for Claude Code and/or Codex.
# Usage: ./install.sh [--claude] [--codex] [--no-cli]
#   With no target flags, installs for every agent whose home folder exists (~/.claude, ~/.codex).
#   --no-cli  do not install @playwright/cli if it is missing (fail instead).
# Safe to rerun: it updates the skill and keeps an existing ~/.playwright/cli.config.json
# and existing browser profiles.
set -euo pipefail
cd "$(dirname "$0")"
want_claude=0; want_codex=0; install_cli=1
for a in "$@"; do case "$a" in
  --claude) want_claude=1;; --codex) want_codex=1;; --no-cli) install_cli=0;;
  -h|--help) sed -n '2,8p' "$0"; exit 0;; *) echo "unknown option: $a" >&2; exit 2;; esac; done
if [ $want_claude = 0 ] && [ $want_codex = 0 ]; then
  [ -d "$HOME/.claude" ] && want_claude=1
  [ -d "$HOME/.codex" ] && want_codex=1
fi
[ $want_claude = 1 ] || [ $want_codex = 1 ] || { echo "Neither ~/.claude nor ~/.codex found; pass --claude or --codex." >&2; exit 1; }

say() { printf '%s\n' "$*"; }
[ "$(uname -s)" = Darwin ] || say "warning: tested on macOS only. Background tabs and minimizing should work elsewhere, focus restore will not."

# 1. Google Chrome (the skill drives installed Chrome, not Chromium or Chrome for Testing)
if [ "$(uname -s)" = Darwin ] && [ ! -d "/Applications/Google Chrome.app" ] && [ ! -d "$HOME/Applications/Google Chrome.app" ]; then
  say "Google Chrome not found. Install it from https://www.google.com/chrome/ and rerun." >&2; exit 1
fi

# 2. Node and playwright-cli
if ! command -v playwright-cli >/dev/null 2>&1 && [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
  . "${NVM_DIR:-$HOME/.nvm}/nvm.sh" >/dev/null 2>&1 || true
fi
command -v npm >/dev/null 2>&1 || { say "npm not found. Install Node.js 20+ (for example with nvm) and rerun." >&2; exit 1; }
if ! command -v playwright-cli >/dev/null 2>&1; then
  [ $install_cli = 1 ] || { say "playwright-cli not found (run: npm i -g @playwright/cli@latest)" >&2; exit 1; }
  say "installing @playwright/cli globally..."
  npm i -g @playwright/cli@latest
fi
say "playwright-cli $(playwright-cli --version)"

# 3. Official playwright-cli skill inside the npm package (files linked, never copied, so they track CLI updates)
root="$(npm root -g)"
official=""
for c in "$root/@playwright/cli/skills/playwright-cli" \
         "$root/@playwright/cli/node_modules/playwright-core/lib/tools/skills/playwright-cli"; do
  [ -f "$c/SKILL.md" ] && { official="$c"; break; }
done
[ -n "$official" ] || { say "official playwright-cli skill not found under $root/@playwright/cli" >&2; exit 1; }

# 4. Home Playwright config: use installed Google Chrome
mkdir -p "$HOME/.playwright"
if [ -f "$HOME/.playwright/cli.config.json" ]; then
  say "kept existing ~/.playwright/cli.config.json (it should set launchOptions.channel to \"chrome\")"
else
  cp config/cli.config.json "$HOME/.playwright/cli.config.json"; say "wrote ~/.playwright/cli.config.json"
fi

# 5. Browser profile folders (persistent sign-ins live here; never deleted by this script)
mkdir -p "$HOME/playwright-profiles/default" "$HOME/playwright-profiles/auth"
chmod 700 "$HOME/playwright-profiles" "$HOME/playwright-profiles/auth"

install_to() {  # install_to SKILL_DIR SKILL_FILE
  local dir="$1" src="$2"
  if [ -e "$dir" ] && [ ! -f "$dir/.background-browser-skill" ]; then
    local bak; bak="$dir.bak-$(date +%Y%m%d%H%M%S)"; mv "$dir" "$bak"; say "moved the existing $dir to $bak"
  fi
  mkdir -p "$dir/scripts"
  cp "$src" "$dir/SKILL.md"
  cp skill/scripts/*.sh "$dir/scripts/"; chmod +x "$dir/scripts/"*.sh
  # Link the official skill's files, not its folder: a nested file named SKILL.md would show up
  # as a second "playwright-cli" skill next to "browser" (Codex scans skill folders recursively).
  [ -L "$dir/playwright-cli" ] && rm "$dir/playwright-cli"   # older layout: one link to the whole folder
  mkdir -p "$dir/playwright-cli"
  ln -sfn "$official/SKILL.md" "$dir/playwright-cli/REFERENCE.md"
  ln -sfn "$official/references" "$dir/playwright-cli/references"
  touch "$dir/.background-browser-skill"
  say "installed $dir"
}
[ $want_claude = 1 ] && install_to "$HOME/.claude/skills/browser" skill/SKILL.claude.md
[ $want_codex = 1 ] && install_to "$HOME/.agents/skills/browser" skill/SKILL.codex.md

# 6. Self-check on a temporary profile (no sign-ins touched), headless so nothing pops up
dir="$HOME/.claude/skills/browser"; [ $want_claude = 1 ] || dir="$HOME/.agents/skills/browser"
tmp="$(mktemp -d)"
if (cd "$tmp" && "$dir/scripts/browser-up.sh" -s bbs-selftest --profile "$tmp/profile" --headless https://example.com/ >/dev/null \
    && "$dir/scripts/page-snap.sh" -s bbs-selftest example.com | grep -q 'Example Domain'); then
  say "self-check: ok"
else
  say "self-check: FAILED (run the commands in INSTALL.md by hand to see the error)" >&2
fi
(cd "$tmp" && playwright-cli -s bbs-selftest close >/dev/null 2>&1) || true
say "done. Start a new agent session and ask it to use /browser (Claude Code) or \$browser (Codex)."
