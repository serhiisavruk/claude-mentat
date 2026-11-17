# Mentat

[![build](https://github.com/serhiisavruk/claude-mentat/actions/workflows/build.yml/badge.svg)](https://github.com/serhiisavruk/claude-mentat/actions/workflows/build.yml)
[![release](https://img.shields.io/github/v/release/serhiisavruk/claude-mentat)](../../releases/latest)
[![license](https://img.shields.io/github/license/serhiisavruk/claude-mentat)](LICENSE)

**See what Claude Code costs you, right in the macOS menu bar.**

```text
$19 / $282 (47%) / $600
```

This means: **$19 today**, **$282 this month**, which is **47 %** of your **$600 monthly budget**. The numbers turn yellow, orange, then red as you get close to your budget.

- Updates every 5 minutes. No window, no Dock icon.
- Counts all your Claude Code projects on this Mac. Sends no data anywhere.
- One small Swift file. You can read every line.

> Unofficial tool. It is not made, supported or endorsed by Anthropic. The cost is an estimate at API list prices.

## Contents

1. [Install](#install)
2. [Set your budget](#set-your-budget)
3. [Use it](#use-it)
4. [Update and uninstall](#update-and-uninstall)
5. [FAQ](#faq)
6. [Troubleshooting](#troubleshooting)
7. [Reference](#reference): settings, prices, file locations, log file

## Install

You need a Mac with Apple Silicon, **macOS 12 or newer**, and **Claude Code** used on that Mac. Open Terminal and paste:

```bash
curl -fsSL https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh | bash
```

**Done.** Your cost appears in the menu bar within a few seconds. Mentat starts again each time you log in.

If the installer says to add `~/.local/bin` to your PATH, run the line it shows. Then the `mentat` command works in Terminal.

<details>
<summary>Check the file before you run it</summary>

```bash
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh.sha256
shasum -a 256 -c install-prebuilt.sh.sha256     # prints: install-prebuilt.sh: OK
less install-prebuilt.sh                         # read it
bash install-prebuilt.sh
```
</details>

<details>
<summary>Or build from source</summary>

Compile the app yourself from the code in this repository. You need the Xcode Command Line Tools (`xcode-select --install`). This also works on Intel Macs, but Intel is not tested.

```bash
git clone https://github.com/serhiisavruk/claude-mentat.git
cd claude-mentat
bash install.sh
```

It is the same app. The one-line installer is built from this code.
</details>

<details>
<summary>What the installer does</summary>

- Puts the app in `~/.config/mentat/Mentat`. The source install compiles it. The one-line install unpacks a ready copy.
- Writes the default settings to `~/.config/mentat/config.json`. If you install again, it keeps your settings.
- Adds the `mentat` command: a link in `~/.local/bin`. If another program called `mentat` is already there, it leaves that program alone.
- Makes Mentat start when you log in. The file is `~/Library/LaunchAgents/com.mentat.plist`.
- Starts the app.

It needs no admin password. It writes only to `~/.config/mentat/`, `~/.local/bin/mentat`, `~/Library/LaunchAgents/` and `~/Library/Logs/Mentat/`.
</details>

## Set your budget

The default budget is **$600 per month**. It is only an example. Set your own:

1. Click the title in the menu bar.
2. Choose **Open config**.
3. Type your **Monthly limit ($)** and click **Save**.

The title updates at once. To change the budget later, do the same steps.

## Use it

### The title

| Part | Meaning |
|---|---|
| `$19` | Cost today, since midnight (your time) |
| `$282` | Cost this month, since the 1st at 00:00 UTC |
| `(47%)` | Month cost as a percent of your monthly budget |
| `$600` | Your monthly budget |

You can change what the title shows. See [Settings](#settings).

### Colours

| Colour | When (default) |
|---|---|
| Yellow | 70 % of the budget |
| Orange | 80 % |
| Red | 90 % |

- **Today** turns colour when today's cost reaches a level of your **day budget**. Day budget = monthly budget ÷ weekdays (Mon–Fri) this month. Example: $600 ÷ 20 days = $30 per day. Public holidays are not removed.
- **Month** and **%** turn colour when the month cost reaches a level of your **monthly budget**.

### The menu

Click the title to open the menu. It shows:

- Alert lines, if a budget level is reached.
- Your cost for the **last 5 hours**, **today**, the **last 7 days** and **this month**, each split by model.
- Your budget per month and per day.
- **No price for: …** if a model has no price. See [Troubleshooting](#troubleshooting).

Then these items:

| Item | Shortcut | What it does |
|---|---|---|
| Refresh | ⌘R | Read the logs now. Don't wait 5 minutes. |
| Open config | ⌘, | Open the settings form. |
| Open log | ⌘L | Open the log file. |
| Start at login | | On or off. A check mark means on. |
| Mentat 2.0.1 | | The installed version (greyed out). |
| Quit | ⌘Q | Close the app. |

The shortcuts work while the menu is open.

### The `mentat` command

Use it in Terminal:

```bash
mentat              # status: running or not, version, start at login, file locations
mentat stop         # quit the app
mentat start        # start the app
mentat restart      # stop, then start
mentat print        # print the current numbers
mentat version      # print the version
mentat uninstall    # remove Mentat completely
mentat help         # list the commands
```

**Quit** in the menu does the same as `mentat stop`. If **Start at login** is on, Mentat starts again at your next login.

## Update and uninstall

**Update:** run the install command again. Your settings and your **Start at login** choice stay the same.

```bash
curl -fsSL https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh | bash
```

If you built from source:

```bash
cd claude-mentat && git pull && bash install.sh
```

An update never changes your `config.json`, so new prices in a new version do not reach your file. Add them by hand if you need them. See [Prices](#prices).

**Uninstall:** removes the app, its settings, the login item, the `mentat` command and the logs.

```bash
mentat uninstall
```

## FAQ

**Is this what I really pay?**
No. Mentat estimates the cost at API list prices. On a Pro or Max subscription you pay your plan price, not this amount. Use the number to see how much you use.

**Does it send my data anywhere?**
No. It reads local files in `~/.claude/projects/` and makes no network calls.

**Which Claude Code use does it count?**
All projects on this Mac, from any Claude Code app that writes to `~/.claude/projects/`. It does not count use on other computers.

**How soon do numbers appear?**
A few seconds after the start. Then every 5 minutes. Choose **Refresh** to update now.

**Does it slow down my Mac?**
No. A refresh takes a second or two every 5 minutes. With 600 MB of Claude Code logs, one refresh took 1.7 seconds and 120 MB of memory.

**Do I need an Apple Developer account, or to allow the app in Security settings?**
No. The app is built or unpacked on your own Mac, so macOS does not block it. On a company-managed Mac, your IT rules may still block unsigned apps.

**Intel Mac?**
Use [build from source](#install). It may work, but it is not tested. The one-line install is for Apple Silicon only.

## Troubleshooting

| Problem | Fix |
|---|---|
| `mentat: command not found` | Run `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc`. Or use the full path: `~/.config/mentat/Mentat status`. |
| `swiftc not found` (source install) | Run `xcode-select --install`, wait for it to finish, then run the installer again. Or use the one-line install. |
| No title in the menu bar | Run `mentat status`. If Mentat runs, your menu bar may be full: close some menu bar apps. An empty **Title template** also hides the title. |
| The title stays `…` | Run `mentat print` to see the numbers in Terminal. Then read `~/Library/Logs/Mentat/mentat.log` and `launchd.log`. |
| The title shows `$0 / $0 (0%) / …` | Claude Code has no use in this period yet. This is normal. |
| The title is only `$0` | The settings file is missing or broken, so Mentat uses default settings. Open the log and look for `config file`. To get a new default file, delete `~/.config/mentat/config.json` and run the install command again. |
| The menu shows `No price for: …` | That model has no price, so its cost is not counted. Add a price in `config.json`. See [Prices](#prices). |
| It doesn't start at login | Click the title and turn on **Start at login**. `mentat status` then shows `Start at login: on`. |

## Reference

### Settings

Choose **Open config** in the menu. Changes apply when you click **Save**. You don't need to restart.

| Setting | Meaning | Default |
|---|---|---|
| Refresh (seconds) | How often Mentat reads the logs. Minimum 10. | 300 |
| Monthly limit ($) | Your monthly budget in USD. 0 turns off alerts and shows `-` for the percent. | 600 |
| Title template | The text in the menu bar. See below. | `${today} / ${month} ({pct}) / ${limit}` |
| Show windows | The time windows in the menu: 5h, today, 7d, month. Keep at least one. | all |
| Alerts (% of budget) | Yellow, orange and red levels. Each must be the same or higher than the one before. Leave one empty to turn it off. | 70, 80, 90 |
| Cache write 5m × / 1h × | Advanced. Leave as is unless Anthropic changes its prices. | 1.25, 2.0 |

<details>
<summary>Title template</summary>

Variables: `{today}` `{month}` `{limit}` `{pct}` `{5h}` `{7d}`. Put `$` in front for a dollar sign, for example `${today}`.

| Template | Menu bar shows |
|---|---|
| `${today} / ${month} ({pct}) / ${limit}` (default) | `$19 / $282 (47%) / $600` |
| `${month}` | `$282` |
| `{pct}` | `47%` |
| `today ${today} · 5h ${5h}` | `today $19 · 5h $6` |

If an alert is on but the template has no coloured value (`{today}`, `{month}` or `{pct}`), the whole title turns colour.
</details>

### Prices

The form does not show the prices. Click **Open file (prices)…** in the form, or open `~/.config/mentat/config.json`. After you edit the file by hand, choose **Refresh**.

Each price is USD per 1 million tokens: `[input, output, cache read]`. Mentat uses the longest price name that matches the start of the model name. Check the prices against the Anthropic pricing page. Prices change.

### Where things are

| What | Where |
|---|---|
| App | `~/.config/mentat/Mentat` |
| `mentat` command | `~/.local/bin/mentat` (a link to the app) |
| Settings | `~/.config/mentat/config.json` |
| Log | `~/Library/Logs/Mentat/mentat.log` |
| Startup errors | `~/Library/Logs/Mentat/launchd.log` |
| Login item | `~/Library/LaunchAgents/com.mentat.plist` |

The folder `~/.config/mentat/` also holds `VERSION` and `.lock`. The lock makes sure only one copy runs.

<details>
<summary>Control Mentat with plain macOS commands</summary>

| Action | Command |
|---|---|
| Status | `pgrep -lx -u $(id -u) Mentat` |
| Stop | `pkill -x -u $(id -u) Mentat` |
| Start | `nohup ~/.config/mentat/Mentat run >/dev/null 2>&1 &` (a second copy exits by itself) |
| Unload the login item and quit now | `launchctl bootout gui/$(id -u)/com.mentat` |
| Load the login item and start now | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mentat.plist` |

Unloading does not delete the login item file, so Mentat still starts at your next login. To turn that off, use **Start at login** in the menu.
</details>

<details>
<summary>Log file</summary>

Mentat writes important events to `~/Library/Logs/Mentat/mentat.log`. Open it with **Open log**, or in the Console app under **Log Reports**.

Each line has a time, a level (INFO, WARN or ERROR) and a message. Mentat logs:

- The app starts or quits. A second copy that exits at once.
- The settings file is missing or broken, and when it is OK again.
- You save the settings. You turn **Start at login** on or off, or the change fails.
- An alert level changes, for example `alert day: none -> orange`.
- A model has no price.
- A refresh takes more than 5 seconds.

A missing or broken settings file and a missing price are logged once, not on every refresh. The file rotates at 512 KB to `mentat.log.1`. It holds no prompts, no file contents and no secrets.

`launchd.log` in the same folder holds the app's own output when it starts at login or with `mentat start`.
</details>

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

MIT. See [LICENSE](LICENSE).
