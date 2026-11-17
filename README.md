# Mentat

Menu bar app for macOS (Apple Silicon, macOS 12+). It shows your estimated Claude Code cost and changes colour when you near your budget. It reads local Claude Code logs only and sends no data anywhere.

## Install

```
bash install.sh              # install or update
bash install.sh uninstall    # remove
```

`install.sh` is one self-contained file. It holds the compiled binary. No Xcode or Python is needed on the user's Mac.

## Files

| File | Purpose |
|---|---|
| `Mentat.swift` | The whole app: usage estimate, menu bar, settings form, log file |
| `config.json` | Default settings and price table |
| `build-installer.py` | Compiles `Mentat.swift` and writes `install.sh` (needs Xcode on the build Mac only) |
| `install.sh` | Generated installer. Do not edit by hand |
| `usage.py` | Old Python version of the estimate. Kept as a reference. Not installed |

## Build a new installer

1. Change the version in `Mentat.swift` (`appVersion`).
2. Run `python3 build-installer.py`.
3. Attach the new `install.sh` where you share it.

## Run and debug

- `~/.config/mentat/Mentat --print` prints the current numbers and exits.
- Settings: `~/.config/mentat/config.json`.
- Log: `~/Library/Logs/Mentat/mentat.log`.

The cost is an estimate at API list prices. Check the price table in `config.json` against the Anthropic pricing page.
