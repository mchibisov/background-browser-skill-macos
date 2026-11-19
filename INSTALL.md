# Install (instructions for an agent)

You are installing the `/browser` skill for Claude Code and/or Codex on macOS. Follow the steps in order and report the result of each check. Do not delete existing browser profiles or auth files, and never print cookies or tokens.

## 1. Check requirements

```bash
sw_vers -productVersion
ls -d "/Applications/Google Chrome.app" || ls -d "$HOME/Applications/Google Chrome.app"
node --version   # 20 or newer; if missing and nvm exists: . "$HOME/.nvm/nvm.sh"
ls -d ~/.claude ~/.codex 2>/dev/null
```

If Chrome or Node is missing, stop and ask the user to install it.

## 2. Run the installer from the cloned repository

```bash
./install.sh            # every agent whose home folder exists
./install.sh --claude   # only Claude Code
./install.sh --codex    # only Codex
```

It does the following (all idempotent):

1. Installs `@playwright/cli` globally with npm if `playwright-cli` is missing (`--no-cli` to skip and fail instead).
2. Finds the official playwright-cli skill inside the npm package and links its files into `<skill>/playwright-cli/` (`REFERENCE.md`, `references/`), so they update with the CLI. The link is not named `SKILL.md`, so neither agent shows `playwright-cli` as a second skill next to `browser`.
3. Writes `~/.playwright/cli.config.json` (`channel: chrome`) only if it does not exist.
4. Creates `~/playwright-profiles/default` and `~/playwright-profiles/auth` (mode 700).
5. Copies `SKILL.md` and `scripts/` to `~/.claude/skills/browser` and/or `~/.agents/skills/browser`. A different existing `browser` skill is moved to `browser.bak-<timestamp>`, not deleted.
6. Runs a headless self-check on a temporary profile and prints `self-check: ok`.

## 3. Verify

```bash
test -f ~/.claude/skills/browser/playwright-cli/REFERENCE.md && echo claude-ok
test -f ~/.agents/skills/browser/playwright-cli/REFERENCE.md && echo codex-ok
```

Headed background mode (a minimized Chrome window opens on a temporary profile; the user's current app must keep focus):

```bash
cd "$(mktemp -d)" && ~/.claude/skills/browser/scripts/browser-up.sh -s check --profile "$PWD/p" https://example.org/
~/.claude/skills/browser/scripts/page-snap.sh -s check example.org
playwright-cli -s check close
```

For Codex, use `~/.agents/skills/browser/scripts/` instead. Expected: `started headed, minimized, focus returned to <app>`, then a short snapshot with `Example Domain`.

## 4. Optional

- If an older setup left a standalone `playwright-cli` skill (for example `~/.agents/skills/playwright-cli` or `~/.claude/skills/playwright-cli`), tell the user: it duplicates `browser`. Disable it in Codex with a `[[skills.config]]` entry (`path` = its `SKILL.md`, `enabled = false`) in `~/.codex/config.toml`, or move it away, only after the user agrees.

- Add one line to `~/.codex/AGENTS.md` (and to `~/.claude/CLAUDE.md` for Claude):
  `Browser tasks: use the browser skill. A headed browser must stay minimized and never take focus: use the skill's scripts and never tab-new, tab-select, or bringToFront there.`
  Ask the user before editing these files.

## 5. Tell the user

- Start a new session and use `/browser` (Claude Code) or `$browser` (Codex).
- The first time on a site that needs an account, the agent un-minimizes the window and the user signs in. The profile keeps the sign-in.

## Uninstall

```bash
mv ~/.claude/skills/browser ~/.claude/skills/browser.removed
mv ~/.agents/skills/browser ~/.agents/skills/browser.removed
```

Profiles in `~/playwright-profiles` hold sign-ins: remove them only if the user asks.
