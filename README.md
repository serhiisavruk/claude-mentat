# Mentat

Mentat is a small menu bar app for macOS. It shows your estimated Claude Code cost for today, this month, and other windows. It changes the colour of the title when your cost gets close to your budget.

```
$19 / $282 (47%) / $600
```

> Unofficial tool. It is not made, supported or endorsed by Anthropic. The cost is an estimate.

## Install

The source code is the core of the project. You build the app on your own Mac. Then you can read every line that runs.

You need:
- macOS 12 or newer.
- Xcode Command Line Tools. To install them, run `xcode-select --install`.
- Claude Code, used on this Mac. Mentat reads the logs that Claude Code writes in `~/.claude/projects/`.

Then run:

```
git clone https://github.com/serhiisavruk/claude-mentat.git
cd claude-mentat
bash install.sh
```

Look at the menu bar. The title shows your cost. The app starts again each time you log in.

The build is for the Mac that you use. Apple Silicon is the tested platform. Intel Macs are not tested.

### Install without Xcode

You can also use a prebuilt installer. It is one file that holds a compiled binary for Apple Silicon. It needs no Xcode. CI builds it from the same source and attaches it to each [release](../../releases/latest).

```
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh
bash install-prebuilt.sh
```

Each release also has `install-prebuilt.sh.sha256`. To check the download:

```
curl -fsSLO https://github.com/serhiisavruk/claude-mentat/releases/latest/download/install-prebuilt.sh.sha256
shasum -a 256 -c install-prebuilt.sh.sha256
```

The prebuilt installer does the same as `install.sh`. The only difference is that it does not build the app.

### What the script does

- Builds `Mentat.swift` with `swiftc` into `~/.config/mentat/Mentat`.
- Writes the default settings file `~/.config/mentat/config.json`. It keeps your own settings if you install again.
- Adds a login item: `~/Library/LaunchAgents/com.mentat.plist`.
- Starts the app.

The script does not use the network. It does not write outside these folders: `~/.config/mentat/`, `~/Library/LaunchAgents/` and `~/Library/Logs/Mentat/`.

### Check the install

```
pgrep -lf Mentat
launchctl print gui/$(id -u)/com.mentat | grep state
tail -5 ~/Library/Logs/Mentat/mentat.log
```

The first command shows the process. The second command shows `state = running`. The third command shows a `start version` line.

### Update

```
cd claude-mentat
git pull
bash install.sh
```

Your settings stay. The script stops the old app and starts the new one.

### Uninstall

```
bash install.sh uninstall
```

This stops the app. It removes `~/.config/mentat/`, the login item and the log folder `~/Library/Logs/Mentat/`.

## Use Mentat

Mentat has no window and no Dock icon. You control it from the menu bar title and from Terminal.

### Menu

Click the title to open the menu.

| Item | Key | Action |
|---|---|---|
| Refresh | R | Read the logs now. Mentat does not wait for the next refresh time. |
| Open config | , | Open the settings form. |
| Open log | L | Open the log file. |
| Start at login | | Turn the start at login on or off. A check mark shows that it is on. |
| Quit | Q | Close the app. |

### Close, start and restart

| Action | Command |
|---|---|
| Close | Choose **Quit**, or run `pkill -x Mentat`. The app stays closed until your next login. |
| Start by hand | `open ~/.config/mentat/Mentat` |
| Start through the login item | `launchctl kickstart gui/$(id -u)/com.mentat` |
| Restart | Run `pkill -x Mentat`, then start the app again. |

You do not need a restart after you change a setting. Save in the settings form, and the menu updates. Edit `config.json` by hand? Choose **Refresh** in the menu.

To see the current numbers in Terminal, run `~/.config/mentat/Mentat --print`.

### Start at login

The install script turns on start at login. To turn it on or off, choose **Start at login** in the menu. A check mark means that the app starts at login. The change takes effect at your next login. It does not start or stop the running app.

The menu item makes or deletes the file `~/Library/LaunchAgents/com.mentat.plist`. You can also use Terminal:

| Action | Command |
|---|---|
| Turn off start at login (no change to the running app) | `rm ~/Library/LaunchAgents/com.mentat.plist` |
| Stop the app now and unload the login item | `launchctl bootout gui/$(id -u)/com.mentat` |
| Load the login item and start the app now | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.mentat.plist` |
| Check if the login item is loaded | `launchctl print gui/$(id -u)/com.mentat` |

## Settings

Choose **Open config** in the menu. A form opens. The settings are saved in `~/.config/mentat/config.json`.

| Setting | Meaning |
|---|---|
| Refresh (seconds) | How often Mentat reads the logs. Minimum 10. |
| Monthly limit ($) | Your monthly budget in USD. **Change this to your own value.** The default is only an example. |
| Title template | The text in the menu bar. Variables: `{today}` `{month}` `{limit}` `{pct}` `{5h}` `{7d}`. |
| Show windows | Time windows in the menu: 5h, today, 7d, month. |
| Alerts (% of budget) | Yellow, orange and red levels. Default: 70, 80, 90. |
| Cache write 5m / 1h | Price multipliers for the prompt cache. Change only if Anthropic changes its prices. |

The form does not show the price table. To edit the prices, click **Open file (prices)…** in the form.

### How alerts work

- Month budget = monthly limit.
- Day budget = monthly limit divided by the working days this month (Monday to Friday). Public holidays are not removed.
- A day alert colours the **today** value. A month alert colours the **month** value and the percent.
- Leave a level empty to turn it off.

## Log file

Mentat writes important events to `~/Library/Logs/Mentat/mentat.log`. This is the standard place for app logs on macOS. Choose **Open log** in the menu to open it. The Console app shows it under **Log Reports**.

Each line has a time, a level (INFO, WARN or ERROR) and a message. Mentat writes these events:

- The app starts or quits.
- The settings file is missing or is not valid JSON. Mentat then uses default values.
- You save the settings or change **Start at login**.
- An alert level changes, for example `alert day: none -> orange`.
- A model has no price in the price table. Mentat does not count its cost.
- A refresh takes more than 5 seconds.

Mentat writes a repeating problem only one time. The file has a limit of 512 KB. When it is full, Mentat keeps the old file as `mentat.log.1` and starts a new file. The log has no prompts, no file contents and no secrets.

A second file, `launchd.log`, is in the same folder. It holds the text output and the error output of the app when macOS starts it at login.

## Privacy and limits

- Mentat reads local files only. It sends no data to any server.
- **The cost is an estimate.** Mentat uses API list prices. If you use a subscription plan, you do not pay this amount.
- The price table is in `config.json`. Check it against the Anthropic pricing page. Prices change.
- Mentat counts only this Mac. It does not count Claude Code use on other computers.

## Problems

| Problem | Action |
|---|---|
| `install.sh` says that `swiftc` is not found | Run `xcode-select --install`. Wait for it to finish. Run the script again. Or use the prebuilt installer. |
| The menu bar shows `error` | Click the title and read the message. Then choose **Open log**. |
| The title shows `$0` | Claude Code has no log entries in this period, or the logs are in another folder. |
| A model has a cost of $0 | The model has no price. Open the log and look for `no price for model(s)`. Add a price in `config.json`. |
| No title appears | Your menu bar may be full. Close some menu bar apps. Then look at `~/Library/Logs/Mentat/launchd.log`. |
| The app does not start at login | Check that **Start at login** has a check mark. Or run `launchctl print gui/$(id -u)/com.mentat`. If it fails, run `bash install.sh` again. |

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md).

## License

MIT. See [LICENSE](LICENSE).
