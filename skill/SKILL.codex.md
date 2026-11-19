---
name: browser
description: Use for ANY browser task (open or check a website, log in, fill a form, scrape, screenshot, test a page, debug a web app, write or run Playwright tests). Drives Google Chrome through the global playwright-cli, with the user's rules for profiles, headless/headed mode, show, Cloudflare sites, parallel multi-site work in background tabs, forms and auth state, and points to the official playwright-cli command reference. Load this before the first playwright-cli command; no other browser skill is needed.
---

# Browser work (playwright-cli + the user's rules)

Before the first command, read the official playwright-cli skill at `$HOME/.agents/skills/browser/playwright-cli/SKILL.md` (a symlink to the installed npm package, so it always matches the CLI version). Detailed guides: `$HOME/.agents/skills/browser/playwright-cli/references/*.md` (read only the one you need). If the link is broken, rerun the installer.

The user's rules below override the official skill where they differ.

## Tool choice
- Use playwright-cli (shell). Do NOT use Computer Use, the built-in browser, or a browser extension unless the user explicitly asks for one of them or playwright-cli cannot do the task. Prefer an API or MCP when no browser is needed.

## Browser and profiles
- Browser: Google Chrome via `~/.playwright/cli.config.json` (`channel: chrome`; `browserName: chromium` is the engine). Never switch to Chromium, Chrome for Testing, or Headless Shell. Never attach or copy the user's main Chrome profile.
- If a project Playwright config conflicts with the home one, pass `open --config="$HOME/.playwright/cli.config.json"`.
- Signed-in work: `--profile="$HOME/playwright-profiles/default"`. It is persistent and keeps logins by itself, so never `state-load` into it (an old snapshot can overwrite fresh cookies). Only one browser can run on a profile; more sessions share it through `attach` (see Multi-site work). For throwaway work use a temporary profile (no `--profile`).

## Headless, show, headed
- Headless by default. When the user asks to see what is happening, run `playwright-cli show` (a separate Google Chrome window mirroring the headless browser; the lock button enables interactive mode so the user can take over mouse and keyboard, Escape releases). Do not open a new headed window for that.
- `open --headed` only for manual sign-in, CAPTCHA (the user completes it), or sites that block headless (below); never solve CAPTCHA yourself. To sign in: `close` the headless session, `open --headed` with the same profile, wait for the user, `close`, then continue headless.
- Sites behind Cloudflare or similar bot checks (for example chatgpt.com) block headless Chrome: use the headed background mode below. Never try to bypass bot detection (flags, user-agent tricks).

## Headed background mode and multi-site work (ChatGPT, Gemini, Flow, ...)
One headed Chrome per profile, minimized, never taking the user's focus; every site in its own background tab; one playwright-cli session per site so sites run in parallel. Scripts: `$HOME/.agents/skills/browser/scripts/` (verified on Chrome 157, macOS).
- Start or reuse, and open the site tabs in the background: `$HOME/.agents/skills/browser/scripts/browser-up.sh -s web https://chatgpt.com/ https://gemini.google.com/app`. It reuses a running session, attaches to a browser already running on that profile (even from another project), or launches one, minimizes it via CDP and gives focus back to the user's app. It also installs a guard so `target=_blank` links and `window.open` stay in the same tab (a popup would bring Chrome to the front). Rerunning it is safe.
- One session per site, attached to the same browser: `$HOME/.agents/skills/browser/scripts/browser-up.sh -s gpt-1 https://chatgpt.com/`, `$HOME/.agents/skills/browser/scripts/browser-up.sh -s gem-1 https://gemini.google.com/app`. Sessions work at the same time (a long wait in one does not block another). The first session owns the browser.
- More background tabs: `$HOME/.agents/skills/browser/scripts/bg-tab.sh -s <session> <url>...` (a URL whose host already has a tab is reused). Use final URLs, since tabs are matched by host after redirects: Flow is `https://flow.google.com/` (labs.google/fx/tools/flow redirects there).
- In headed mode never run `tab-new`, `tab-select`, `bringToFront`, `show`, or `open` of a second window: they bring Chrome to the front and un-minimize it. Each session's current tab stays tab 0 (often about:blank), so plain `snapshot`/`click` act on it. Read site tabs by URL with `$HOME/.agents/skills/browser/scripts/page-snap.sh -s gpt-1 chatgpt.com` (see Token budget) and act with `run-code`:
  `playwright-cli -s gpt-1 run-code "async page => { const p = page.context().pages().find(p => p.url().includes('chatgpt.com')); await p.locator('aria-ref=e12').click() }"`
  Snapshots have `[ref=eN]`; act with `p.locator('aria-ref=eN').click()`, `.fill()`, `p.keyboard`, `p.setInputFiles()`. goto, click, typing, uploads, downloads, dialogs and screenshots of a background tab do not take focus. Timers and animations keep running in a minimized window.
- Long jobs (generation, research): submit, return, then poll in short `run-code` calls instead of one long wait, and work on other sites meanwhile. Save results with `download.saveAs()` into the project folder and keep progress (site, tab URL, prompt, status, output path) in a small JSON file there, so a new session can resume.
- If a window pops up anyway (manual click, a site opening one): `$HOME/.agents/skills/browser/scripts/browser-hide.sh -s <session>`.
- Sign-in or CAPTCHA: un-minimize only that browser (`playwright-cli -s <session> run-code` with `Browser.setWindowBounds` `windowState: 'normal'`), ask the user to finish, then run `browser-hide.sh`.
- Finish: site sessions `detach` (the browser keeps running); the owner session runs `close` only when all work is done, since every launch can briefly take focus. Never `close` or `detach` sessions you did not start, and do not install the guard in someone else's browser.
- Sessions belong to the current workspace (git root or cwd). `playwright-cli list` shows only this workspace; `playwright-cli list --all` shows every running browser. `browser-up.sh` already handles this by attaching.
- Off-screen positions and `--start-minimized` do not work on macOS; hiding the app (Cmd+H) is undone by a new tab, so minimize instead.

## Token budget
- A full snapshot of a heavy page costs 8k to 20k tokens (measured: Flow about 8k, a GitHub repo page about 18k), more than a screenshot (about 1.2k at 1280x720). Gemini or ChatGPT pages are 1k to 2k.
- Start shallow, then expand only what you need: `$HOME/.agents/skills/browser/scripts/page-snap.sh -s <session> <url-part>` (depth 4 overview, usually under 500 tokens), then `--ref eN` for one block, `--grep "Send|textbox"` to find controls, or `--interactive` for controls only. Output is capped at 8000 chars.
- In the current tab (headless or non-site work) use `playwright-cli snapshot --depth=4` or `snapshot <ref>` the same way.
- Batch actions into one `run-code` call and return only what you need (a status, a URL, a short text), never whole pages. Take screenshots only to check visuals, and of an element rather than the full page.

## Auth state
- `state-save "$HOME/playwright-profiles/auth/<site>.json"` (then `chmod 600`) only to seed parallel or temporary sessions, or as a backup when the user asks. `state-load` such files only into those sessions.
- Never print cookies, tokens, or state files, or put auth data in artifacts. Close your session with `close`; never delete profiles or auth snapshots.

## Efficiency
- Forms: take one snapshot, then fill the whole form in one `playwright-cli run-code "async page => { ... }"` call; snapshot again only after submit or navigation. If it fails or the form changes as you fill it (dependent fields, multi-step), take a new snapshot and continue step by step.
- Use focused `snapshot`, `find`, and `--raw`; screenshots only for visual checks. After the first successful pass of a repeated flow, offer to save it as a Playwright script so reruns cost no tokens.
