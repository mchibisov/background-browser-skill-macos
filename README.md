# background-browser-skill-macos

[Русская версия](README.ru.md)

A `/browser` skill for **Claude Code** and **Codex** that lets the agent work in several websites at once (ChatGPT, Gemini, Google Flow, any web app) in **background tabs of a minimized Google Chrome**, without stealing your focus and with small token use. Built on Microsoft's [playwright-cli](https://github.com/microsoft/playwright-cli).

## What problems it solves

| Problem | What the skill does |
|---|---|
| Chrome pops up and steals focus while you work | Starts Chrome once, minimizes it, gives focus back to your app. New tabs open in the background. Popups (`target=_blank`, `window.open`) are kept in the same tab. |
| The agent works through sites one by one | One playwright-cli session per site, all attached to the same browser, so they run in parallel. |
| Sites behind Cloudflare block headless Chrome | Uses a real headed Chrome with a persistent profile, just minimized. No bot-detection tricks. |
| Screenshots and huge page snapshots burn tokens | `page-snap.sh` gives a shallow overview (usually under 500 tokens), then only the block you ask for. A full snapshot of a heavy page is 8k to 20k tokens. |
| You log in again and again | A persistent profile keeps sign-ins. You do login and CAPTCHA yourself, once. |
| The agent picks a random browser tool | One skill with clear rules: playwright-cli first, built-in browsers and Computer Use only on request. |

## Why not just the official playwright-cli skill?

The official skill is a command reference, and this skill includes it (linked from the installed package, so it always matches your CLI version). On top of it, this skill adds rules (profiles, headless vs headed, auth state, token budget) and four small scripts:

- `browser-up.sh`: start or reuse a minimized Chrome, return focus, add the popup guard, open site tabs in the background. If a browser on that profile already runs (even from another project), it attaches instead of failing on the profile lock.
- `bg-tab.sh`: open more background tabs.
- `page-snap.sh`: token-cheap snapshot of a tab chosen by URL (`--depth`, `--ref`, `--grep`, `--interactive`).
- `browser-hide.sh`: put the window away again.

Do not use `tab-new`, `tab-select` or `bringToFront` in headed mode: they bring Chrome to the front. The skill tells the agent this.

## Compared with other ways to give an agent a browser

Token figures are rough. "Measured" means we measured it for this skill. The other figures come from public reports linked below, or are estimates from screenshot size (about 1.2k to 1.6k tokens per screenshot).

| Tool | How the agent sees the page | Tokens per page read | Steals focus / blocks you | Your sign-ins | Parallel sites | Works from CLI agents |
|---|---|---|---|---|---|---|
| **This skill** | text snapshot with refs, shallow first | **300 to 500 overview, 1k to 2k for ChatGPT/Gemini (measured)**; skill load about 6k once | no (minimized, background tabs) | yes, own persistent profile | yes, session per site | yes (Claude Code, Codex CLI) |
| Official playwright-cli skill alone | text snapshot saved to a file | 1k to 20k when the full file is read | yes in headed mode (new tabs come to front) | yes | manual | yes |
| Playwright MCP | snapshot after every action | 3k to 15k per action, plus about 13k of tool schemas | headed: yes | optional | limited | yes |
| Chrome DevTools MCP (Google) | a11y snapshot or screenshot | 0.3k to 10k snapshot, about 1.6k screenshot; `--slim` cuts schemas | attaches to your Chrome | yes | limited | yes |
| agent-browser (Vercel) | compact snapshot with refs | 0.2k to 0.4k interactive snapshot (reported) | headed: yes | optional | sessions | yes |
| Browser Use CLI / Browser Harness | CDP helpers in your real Chrome | lowest in its own benchmark (2.1M vs 4.4M for Playwright MCP per suite) | works in your Chrome | yes, your profile | yes | yes |
| Claude in Chrome (extension) | a11y tree (`read_page`) plus screenshots | hundreds to a few thousand for the tree, about 1.5k per screenshot; often screenshots by default | works in your visible Chrome | yes, your profile | tab group | via `--chrome` |
| ChatGPT/Codex Chrome extension | DOM plus screenshots (not documented) | no public data | works in your visible Chrome | yes, your profile | tab groups | desktop app only |
| Claude Code Desktop built-in browser | DOM plus screenshots | about 1.2k to 1.6k per screenshot | no (inside the app) | no, clean profile | tabs | desktop app only |
| Codex/ChatGPT app built-in browser | DOM plus screenshots | about 1.2k to 1.6k per screenshot | no (inside the app) | no, separate profile | tabs | desktop app only |
| Computer Use (Claude, Codex) | screenshots of the screen | about 1.2k to 1.6k per step | yes, uses your screen | whatever is open | no | partly |
| AX-tree desktop tools (Cua Driver, Peekaboo) | accessibility tree of apps | low (element refs instead of pixels) | Cua: background input | n/a | n/a | yes (MCP/CLI) |

Short version: for websites, a CLI with text snapshots (this skill, agent-browser, Browser Use CLI) is the cheapest. Use built-in browsers for quick checks of your own localhost app. Use Computer Use only for desktop apps that have no API. Canvas apps such as Figma show only their UI as text: the canvas needs screenshots or the Figma API.

## Install

Requirements: macOS, Google Chrome, Node.js 20+, Claude Code and/or Codex.

**Ask your agent** (Claude Code or Codex):

> Install the browser skill from https://github.com/mchibisov/background-browser-skill-macos: clone it to a temporary folder, read INSTALL.md and follow it.

**Or by hand:**

```bash
git clone https://github.com/mchibisov/background-browser-skill-macos.git
cd background-browser-skill-macos && ./install.sh
```

The installer installs `@playwright/cli` if it is missing and links the official playwright-cli skill into the skill folder. It writes `~/.playwright/cli.config.json` (Google Chrome) only if that file does not exist yet, creates `~/playwright-profiles/`, and runs a headless self-check. Rerunning it is safe. Details and manual steps: [INSTALL.md](INSTALL.md).

## Use

In a new session: `/browser` in Claude Code, `$browser` in Codex, or just ask for a browser task. Example:

> Open ChatGPT and Gemini in the background, send both the same prompt, and save the answers to answers.md.

First time on a site: the agent un-minimizes the window and asks you to sign in. Then it minimizes the window again and continues.

## Status and limits

- Tested on macOS 27, Chrome 157, playwright-cli 0.1.25: focus never left the user's app except about 1 second at launch, the window stayed minimized, and three sessions ran in parallel.
- Linux and Windows: untested. Minimizing and background tabs use Chrome DevTools Protocol and may work. Focus restore is macOS-only.
- Login, CAPTCHA and 2FA are done by you. The skill never tries to bypass bot detection.
- It uses its own Chrome profile (`~/playwright-profiles/default`), never your main Chrome profile.

## Sources for the comparison

[playwright-cli](https://github.com/microsoft/playwright-cli), [agent-browser vs Playwright CLI](https://www.test-lab.ai/blog/agent-browser-vs-playwright-cli), [Context Wars](https://paddo.dev/blog/agent-browser-context-efficiency/), [Chrome DevTools MCP tool reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md), [Browser Harness](https://github.com/browser-use/browser-harness), [Claude browser use tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/browser-use-tool), [Codex browser](https://developers.openai.com/codex/app/browser), [Codex Chrome extension](https://thenewstack.io/openai-codex-chrome-extension/), [Claude Code Desktop browser](https://wmedia.es/en/tips/claude-code-desktop-browser), [Computer use MCP servers](https://pinggy.io/blog/best_computer_use_mcp_servers/).

## License

MIT. The official playwright-cli skill is not included. It is linked from your installed `@playwright/cli` package (Apache-2.0).
