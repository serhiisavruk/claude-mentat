# Development

The source code is the core of the project. Everything else is built from it.

## Files

| File | Purpose |
|---|---|
| `Mentat.swift` | The whole app: usage estimate, menu bar, settings form, log file |
| `config.json` | Default settings and price table |
| `install.sh` | The installer. It builds `Mentat.swift` with `swiftc` and installs the app |
| `~/.local/bin/mentat` | Not a file in git. `install.sh` links it to the installed app. `Mentat <command>` runs a command and exits: status, start, stop, restart, print, uninstall, version, help |
| `build-installer.py` | Makes `install-prebuilt.sh` from `install.sh` and a compiled binary |
| `install-prebuilt.sh` | Generated. Not in git. CI attaches it to each release |
| `usage.py` | Old Python version of the estimate. Kept as a reference. Not installed |
| `.github/workflows/build.yml` | CI: build, test and release |
| `.github/dependabot.yml` | Monthly updates for the GitHub Actions versions in CI |

## Build and run from source

```
bash install.sh            # build, install and start
MENTAT_NO_LAUNCH=1 bash install.sh   # build and install, do not start
~/.config/mentat/Mentat --print      # check that it runs
```

You need the Xcode Command Line Tools. To compile only, without the installer:

```
swiftc -O Mentat.swift -o /tmp/Mentat && /tmp/Mentat --print
```

## Debug

- `Mentat --print` prints the usage text and exits. It does not write to the log.
- The first line of the output is the menu bar title. Colour spans use the control characters RS (`0x1e`), US (`0x1f`) and GS (`0x1d`). Use `cat -v` to see them.
- Log: `~/Library/Logs/Mentat/mentat.log`.

## How the numbers work

- The app reads `~/.claude/projects/**/*.jsonl`, skips duplicate entries (message id and request id), and finds the price by the longest model-name prefix in `config.json`.
- Cost = input, output and cache-read tokens at the model price, plus cache-write tokens at the input price times the 5-minute or 1-hour multiplier.
- The `5h`, `today` and `7d` windows are counted from now and from local midnight. The `month` window starts at the first day of the month in UTC.

## The prebuilt installer

`build-installer.py` compiles `Mentat.swift` for `arm64-apple-macos12`. It compresses the binary with gzip and writes it as base64 text into a copy of `install.sh`. It also embeds the default `config.json`.

`install.sh` has blocks between `# >>> name` and `# <<< name` markers. The names are `checks`, `version`, `config` and `binary`. The generator replaces each block. **Keep the markers when you edit `install.sh`.** The generator stops with an error if a marker is missing.

The whole of `install.sh` is one `main` function that is called on the last line. Bash reads the full function before it runs it, so `curl … | bash` is safe: no command in the script can read the rest of the script from stdin. **Keep new code inside `main`.**

A file that a script writes has no quarantine flag, so Gatekeeper does not block it. The binary has an ad-hoc signature only. It is not notarized.

## CI and release

Every push to `main` and every pull request runs on an Apple Silicon runner (`macos-15`):

1. Install from source, check the app (`--print`), uninstall.
2. Build the prebuilt installer, install it, check the app, check that it targets macOS 12 and arm64, uninstall. It also checks the `mentat` link and the `status`, `version` and `uninstall` commands, and installs through a pipe (`cat install-prebuilt.sh | bash`) like the README one-liner.
3. Write `install-prebuilt.sh.sha256` and save both files as a build artifact.

To make a release:

1. Change `appVersion` in `Mentat.swift` and commit.
2. Tag the commit with the same number and push the tag:

```
git tag v2.0.1
git push origin v2.0.1
```

3. The workflow tests the build and creates a GitHub release with `install-prebuilt.sh` and `install-prebuilt.sh.sha256` attached. It fails if the tag and `appVersion` differ.

## Changes to remember

- Change a price or a default in `config.json`. Users who already installed keep their own `config.json`. The installer never overwrites it.
- Check the price table against the Anthropic pricing page each time Anthropic changes its prices.
- A new menu item or setting needs a change in the README tables.

## Command line and app mode

The one binary is both the menu bar app and the `mentat` command.

- With a command (`mentat stop`, `Mentat --print`), it runs the command and exits. It never opens the menu bar app.
- With no arguments in a terminal, it shows `status`.
- With no arguments and no terminal (launchd at login), or with `run`, it starts the menu bar app.
- The app holds a lock on `~/.config/mentat/.lock` and writes its PID there. A second copy exits at once. `status`, `stop` and `start` use the same lock to see if the app runs.
- Paths come from `$HOME`. The login item sets `HOME` so the app and the installer always use the same folders. To test in a throwaway home: `HOME=/tmp/h bash install.sh`.
