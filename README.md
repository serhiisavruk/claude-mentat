# Mentat

[![build](https://github.com/serhiisavruk/claude-mentat/actions/workflows/build.yml/badge.svg)](https://github.com/serhiisavruk/claude-mentat/actions/workflows/build.yml)
[![release](https://img.shields.io/github/v/release/serhiisavruk/claude-mentat)](../../releases/latest)
[![license](https://img.shields.io/github/license/serhiisavruk/claude-mentat)](LICENSE)

**See what Claude Code costs you, right in the macOS menu bar.**

```
$19 / $282 (47%) / $600
```

That reads as: **$19 today**, **$282 this month**, **47 %** of your **$600 monthly budget**. The numbers turn yellow, orange and then red as you get close to your budget.

- Updates every 5 minutes. No window, no Dock icon.
- Reads only local Claude Code logs. Sends no data anywhere.
- One small Swift file. You can read every line.

> Unofficial tool. It is not made, supported or endorsed by Anthropic. The cost is an estimate at API list prices.

## Contents

- [Install](#install)
- [First step: set your budget](#first-step-set-your-budget)
- [Everyday use](#everyday-use)
- [Settings](#settings)
- [Update and uninstall](#update-and-uninstall)
- [FAQ](#faq)
- [Problems](#problems)

## Install

You need a Mac with **macOS 12 or newer** and **Claude Code** used on that Mac.

### Option A: build from source (recommended)

Needs the Xcode Command Line Tools. Don't have them? Run `xcode-select --install` first.

```
git clone https://github.com/serhiisavruk/claude-mentat.git
cd claude-mentat
bash install.sh
```

### Option B: prebuilt, no Xcode needed (Apple Silicon only)

```
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh
bash install-prebuilt.sh
```

It's the same app, built from the same source by CI. Only the build step is skipped.

<details>
<summary>Verify the download (optional)</summary>

```
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh.sha256
shasum -a 256 -c install-prebuilt.sh.sha256
```

You should see `install-prebuilt.sh: OK`.
</details>

**Done.** Look at the menu bar: your cost appears there. Mentat starts again each time you log in.

<details>
<summary>What the installer does</summary>

- Builds `Mentat.swift` into `~/.config/mentat/Mentat` (Option B unpacks a prebuilt copy instead).
- Writes the default settings to `~/.config/mentat/config.json`. Your own settings are kept if you install again.
- Adds a login item: `~/Library/LaunchAgents/com.mentat.plist`.
- Starts the app.

It does not use the network. It writes only to `~/.config/mentat/`, `~/Library/LaunchAgents/` and `~/Library/Logs/Mentat/`.
</details>

<details>
<summary>Check that it runs</summary>

```
pgrep -lf Mentat                                       # shows the process
launchctl print gui/$(id -u)/com.mentat | grep state   # shows "state = running"
~/.config/mentat/Mentat --print                        # prints the current numbers
```
</details>

## First step: set your budget

The default budget is **$600/month**. It's only an example.

1. Click the title in the menu bar.
2. Choose **Open config**.
3. Enter your **Monthly limit ($)** and save.

The title updates at once.

## Everyday use

Click the title to open the menu.

| Item | Key | What it does |
|---|---|---|
| Refresh | R | Read the logs now, without waiting. |
| Open config | , | Open the settings form. |
| Open log | L | Open the log file. |
| Start at login | | Turn the start at login on or off. A check mark means on. |
| Quit | Q | Close the app until your next login. |

The menu also lists your cost by time window (5h, today, 7d, month) and by model.

### Alert colours

| Colour | Default level |
|---|---|
| Yellow | 70 % of budget |
| Orange | 80 % |
| Red | 90 % |

- **Month budget** = your monthly limit. A month alert colours the month value and the percent.
- **Day budget** = monthly limit ÷ working days this month (Mon–Fri). A day alert colours the today value.

<details>
<summary>Start, stop and restart from Terminal</summary>

| Action | Command |
|---|---|
| Stop | `pkill -x Mentat` |
| Start | `open ~/.config/mentat/Mentat` |
| Start through the login item | `launchctl kickstart gui/$(id -u)/com.mentat` |
| Turn off start at login | `rm ~/Library/LaunchAgents/com.mentat.plist` |
| Stop now and unload the login item | `launchctl bootout gui/$(id -u)/com.mentat` |
| Load the login item and start now | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mentat.plist` |

A change to **Start at login** takes effect at your next login. It doesn't start or stop the running app.
</details>

## Settings

Choose **Open config** in the menu. Changes apply when you save. No restart is needed.

| Setting | Meaning |
|---|---|
| Refresh (seconds) | How often Mentat reads the logs. Minimum 10. Default 300. |
| Monthly limit ($) | Your monthly budget in USD. |
| Title template | The text in the menu bar. Variables: `{today}` `{month}` `{limit}` `{pct}` `{5h}` `{7d}`. Put `$` in front for a dollar sign, e.g. `${today}`. |
| Show windows | Time windows listed in the menu: 5h, today, 7d, month. |
| Alerts (% of budget) | Yellow, orange and red levels. Leave one empty to turn it off. |
| Cache write 5m / 1h | Price multipliers for the prompt cache. Change only if Anthropic changes its prices. |

Prices per model are not in the form. Click **Open file (prices)…** to edit them in `~/.config/mentat/config.json`. After you edit the file by hand, choose **Refresh**.

<details>
<summary>Title template examples</summary>

| Template | Menu bar shows |
|---|---|
| `${today} / ${month} ({pct}) / ${limit}` (default) | `$19 / $282 (47%) / $600` |
| `${month}` | `$282` |
| `{pct}` | `47%` |
| `today ${today} · 5h ${5h}` | `today $19 · 5h $6` |
</details>

## Update and uninstall

**Update** (your settings are kept):

```
cd claude-mentat && git pull && bash install.sh                  # Option A
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh && bash install-prebuilt.sh   # Option B
```

**Uninstall** (removes the app, its settings, the login item and the logs):

```
bash install.sh uninstall        # or: bash install-prebuilt.sh uninstall
```

## FAQ

**Is this what I really pay?**
No. Mentat estimates cost at API list prices. On a Pro or Max subscription you pay your plan price, not this amount. Use the number to see how much you use.

**Does it send my data anywhere?**
No. It reads local files in `~/.claude/projects/` and makes no network calls.

**Does it count Claude Code on my other computers?**
No. It counts only the Mac it runs on.

**Do I need an Apple Developer account or to allow the app in Security settings?**
No. The app is built or unpacked on your own Mac, so Gatekeeper doesn't block it. On a company-managed Mac, your IT rules may still block unsigned apps.

**Intel Mac?**
Option A may work but isn't tested. Option B is Apple Silicon only.

**Are the prices up to date?**
Check the price table in `config.json` against the Anthropic pricing page. Prices change. A new install never overwrites your own `config.json`.

## Problems

| Problem | Fix |
|---|---|
| `swiftc not found` | Run `xcode-select --install`, wait for it to finish, run the installer again. Or use Option B. |
| The menu bar shows `error` | Click the title and read the message. Then choose **Open log**. |
| The title shows `$0` | Claude Code has no log entries in this period yet. |
| A model shows `$0` | The model has no price. Open the log and look for `no price for model(s)`. Add a price in `config.json`. |
| No title appears | Your menu bar may be full. Close some menu bar apps. Then look at `~/Library/Logs/Mentat/launchd.log`. |
| It doesn't start at login | Check that **Start at login** has a check mark. If that doesn't help, run the installer again. |

<details>
<summary>About the log file</summary>

Mentat writes important events to `~/Library/Logs/Mentat/mentat.log`. Open it with **Open log**, or in the Console app under **Log Reports**.

It logs: start and quit, a missing or broken settings file, saved settings, alert level changes (e.g. `alert day: none -> orange`), models with no price, and refreshes slower than 5 seconds. A repeating problem is logged once. The file rotates at 512 KB to `mentat.log.1`. It holds no prompts, no file contents and no secrets.

`launchd.log` in the same folder holds the app's output when macOS starts it at login.
</details>

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

MIT. See [LICENSE](LICENSE).
