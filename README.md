# Mentat

Menu bar app for macOS (Apple Silicon, macOS 12+). It shows your estimated Claude Code cost and changes colour when you near your budget. It reads local Claude Code logs only and sends no data anywhere.

## Install

```
bash install.sh              # install or update
bash install.sh uninstall    # remove
```

`install.sh` is one self-contained file. It holds the compiled binary. No Xcode or Python is needed on the user's Mac. Get it from the latest [Release](../../releases/latest).

## Files

| File | Purpose |
|---|---|
| `Mentat.swift` | The whole app: usage estimate, menu bar, settings form, log file |
| `config.json` | Default settings and price table |
| `build-installer.py` | Compiles `Mentat.swift` and writes `install.sh` (needs Xcode on the build Mac only) |
| `install.sh` | Generated installer. Not in git. GitHub Actions builds it and attaches it to each Release |
| `usage.py` | Old Python version of the estimate. Kept as a reference. Not installed |

## Release

1. Change the version in `Mentat.swift` (`appVersion`) and commit.
2. Tag the commit with the same number: `git tag v2.0.1 && git push origin v2.0.1`.
3. GitHub Actions (`.github/workflows/build.yml`) builds `install.sh` on an Apple Silicon runner, tests an install and an uninstall, and creates a Release with `install.sh` attached. It fails if the tag and `appVersion` differ.

Every push to `main` and every pull request also builds and tests the installer. The result is a build artifact named `install.sh`. Download the latest one:

```
gh run download --name install.sh    # newest run; add a run ID to choose one
```

## Build locally

Needs an Apple Silicon Mac with Xcode Command Line Tools (`xcode-select --install`) and `python3`.

```
python3 build-installer.py                       # compiles Mentat.swift, writes install.sh
MENTAT_NO_LAUNCH=1 bash install.sh               # install without starting the app
~/.config/mentat/Mentat --print                  # check it runs
bash install.sh                                  # install and start it in the menu bar
```

These are the same checks CI runs, see the `Test installer` step in `.github/workflows/build.yml`.

## Run and debug

- `~/.config/mentat/Mentat --print` prints the current numbers and exits.
- Settings: `~/.config/mentat/config.json`.
- Log: `~/Library/Logs/Mentat/mentat.log`.

The cost is an estimate at API list prices. Check the price table in `config.json` against the Anthropic pricing page.
