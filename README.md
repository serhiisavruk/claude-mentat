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
- [Start, stop, restart](#start-stop-restart)
- [Where things are](#where-things-are)
- [Everyday use](#everyday-use)
- [Settings](#settings)
- [Update and uninstall](#update-and-uninstall)
- [FAQ](#faq)
- [Problems](#problems)

## Install

Needs a Mac with Apple Silicon, **macOS 12 or newer**, and **Claude Code** used on that Mac. Paste this into Terminal:

```
curl -fsSL https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh | bash
```

**Done.** Look at the menu bar: your cost appears there. Mentat starts again each time you log in.

<details>
<summary>Prefer to check the file before you run it?</summary>

```
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh.sha256
shasum -a 256 -c install-prebuilt.sh.sha256     # should print: install-prebuilt.sh: OK
less install-prebuilt.sh                         # read it
bash install-prebuilt.sh
```
</details>

### Or build from source

Read every line that runs and compile it yourself. Needs the Xcode Command Line Tools (`xcode-select --install`). Also works on Intel Macs (not tested).

```
git clone https://github.com/serhiisavruk/claude-mentat.git
cd claude-mentat
bash install.sh
```

It's the same app. The one-line installer is built from this source by CI.

<details>
<summary>What the installer does</summary>

- Puts the app in `~/.config/mentat/Mentat`. The source install compiles it. The one-line install unpacks a prebuilt copy.
- Writes the default settings to `~/.config/mentat/config.json`. Your own settings are kept if you install again.
- Adds the `mentat` command: a link in `~/.local/bin`. It never replaces another program called `mentat`.
- Adds a login item: `~/Library/LaunchAgents/com.mentat.plist`.
- Starts the app.

It needs no admin password. It writes only to `~/.config/mentat/`, `~/.local/bin/mentat`, `~/Library/LaunchAgents/` and `~/Library/Logs/Mentat/`.
</details>

## First step: set your budget

The default budget is **$600/month**. It's only an example.

1. Click the title in the menu bar.
2. Choose **Open config**.
3. Enter your **Monthly limit ($)** and save.

The title updates at once.

## Start, stop, restart

Mentat runs in the background for your user. Control it with the `mentat` command:

```
mentat              # status: running? version, login item, file locations
mentat stop         # quit it
mentat start        # start it again
mentat restart      # stop, then start
mentat print        # print the current numbers
mentat uninstall    # remove everything
mentat help         # list the commands
```

You can also quit from the menu: click the title, choose **Quit**. It starts again at your next login. To stop that, turn off **Start at login** in the same menu.

`mentat: command not found`? The command is in `~/.local/bin`, the same folder Claude Code uses. Add it to your PATH once:

```
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

Or use the full path: `~/.config/mentat/Mentat status`.

<details>
<summary>Same with plain macOS commands</summary>

| Action | Command |
|---|---|
| Status | `pgrep -lx -u $(id -u) Mentat` |
| Stop | `pkill -x -u $(id -u) Mentat` |
| Start | `nohup ~/.config/mentat/Mentat run >/dev/null 2>&1 &` (a second copy exits by itself) |
| Unload the login item now | `launchctl bootout gui/$(id -u)/com.mentat` |
| Load the login item and start | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mentat.plist` |
</details>

## Where things are

| What | Where |
|---|---|
| App | `~/.config/mentat/Mentat` |
| `mentat` command | `~/.local/bin/mentat` (a link to the app) |
| Settings | `~/.config/mentat/config.json` |
| Log | `~/Library/Logs/Mentat/mentat.log` |
| Output when started at login | `~/Library/Logs/Mentat/launchd.log` |
| Login item | `~/Library/LaunchAgents/com.mentat.plist` |

That's all of it. Nothing is installed anywhere else.

## Everyday use

Click the title to open the menu. The keys work while the menu is open.

| Item | Key | What it does |
|---|---|---|
| Refresh | ⌘R | Read the logs now, without waiting. |
| Open config | ⌘, | Open the settings form. |
| Open log | ⌘L | Open the log file. |
| Start at login | | Turn the start at login on or off. A check mark means on. |
| Quit | ⌘Q | Close the app. It starts again at your next login. |

The menu also lists your cost by time window (5h, today, 7d, month) and by model.

### Alert colours

| Colour | Default level |
|---|---|
| Yellow | 70 % of budget |
| Orange | 80 % |
| Red | 90 % |

- **Month budget** = your monthly limit. A month alert colours the month value and the percent.
- **Day budget** = monthly limit ÷ working days this month (Mon–Fri). A day alert colours the today value.

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

**Update:** run the install command again. Your settings are kept.

```
curl -fsSL https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh | bash
cd claude-mentat && git pull && bash install.sh      # if you built from source
```

**Uninstall:** removes the app, its settings, the login item and the logs.

```
mentat uninstall
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
Use [build from source](#or-build-from-source). It may work but isn't tested. The one-line install is Apple Silicon only.

**Are the prices up to date?**
Check the price table in `config.json` against the Anthropic pricing page. Prices change. A new install never overwrites your own `config.json`.

## Problems

| Problem | Fix |
|---|---|
| `swiftc not found` | Run `xcode-select --install`, wait for it to finish, run the installer again. Or use the one-line install. |
| The title shows `?` or stays `…` | Click the title and read the menu. Then choose **Open log**. |
| The title shows `$0` | Claude Code has no log entries in this period yet. |
| The menu says `No price for: …` | That model has no price, so its cost is not counted. Add a price in `config.json`. |
| No title appears | Your menu bar may be full. Close some menu bar apps. Then look at `~/Library/Logs/Mentat/launchd.log`. |
| It doesn't start at login | Check that **Start at login** has a check mark. Run `mentat status`. If that doesn't help, run the installer again. |

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
