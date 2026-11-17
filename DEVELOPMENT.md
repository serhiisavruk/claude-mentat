# Development

## Files

| File | Purpose |
|---|---|
| `Mentat.swift` | The whole app: usage estimate, menu bar, settings form, log file |
| `config.json` | Default settings and price table |
| `build-installer.py` | Compiles `Mentat.swift` and writes `install.sh` (needs Xcode on the build Mac only) |
| `install.sh` | Generated installer. Not in git. GitHub Actions builds it and attaches it to each release |
| `usage.py` | Old Python version of the estimate. Kept as a reference. Not installed |
| `.github/workflows/build.yml` | CI: build, test and release |

## How the installer works

`build-installer.py` compiles `Mentat.swift` for `arm64-apple-macos12`. It compresses the binary with gzip and writes it as base64 text into `install.sh`, together with the default `config.json`. The script decodes the binary on the user's Mac. A file that a script writes has no quarantine flag, so Gatekeeper does not block it. The binary has an ad-hoc signature only. It is not notarized.

The app links only system frameworks and the Swift runtime that is part of macOS. The user needs no Xcode and no Python.

## Build on your Mac

```
python3 build-installer.py
bash install.sh
```

`MENTAT_NO_LAUNCH=1 bash install.sh` installs the files and does not start the app.

## Debug

- `~/.config/mentat/Mentat --print` prints the usage text and exits. It does not write to the log.
- The first line of the output is the menu bar title. Colour spans use the control characters RS (`0x1e`), US (`0x1f`) and GS (`0x1d`). Use `cat -v` to see them.
- Log: `~/Library/Logs/Mentat/mentat.log`.

## How the numbers work

- The app reads `~/.claude/projects/**/*.jsonl`, skips duplicate entries (message id and request id), and finds the price by the longest model-name prefix in `config.json`.
- Cost = input, output and cache-read tokens at the model price, plus cache-write tokens at the input price times the 5-minute or 1-hour multiplier.
- The `5h`, `today` and `7d` windows are counted from now and from local midnight. The `month` window starts at the first day of the month in UTC.

## CI and release

Every push to `main` and every pull request builds the installer on an Apple Silicon runner (`macos-latest`). The job then runs an install, checks the app (`--print`, minimum macOS 12, arm64) and runs an uninstall. The installer is saved as the build artifact `install.sh`.

To make a release:

1. Change `appVersion` in `Mentat.swift` and commit.
2. Tag the commit with the same number and push the tag:

```
git tag v2.0.1
git push origin v2.0.1
```

3. The workflow builds and tests `install.sh`. It then creates a GitHub release and attaches the file. The workflow fails if the tag and `appVersion` differ.

## Changes to remember

- Change a price or a default in `config.json`. Users who already installed keep their own `config.json`. The installer never overwrites it.
- Check the price table against the Anthropic pricing page each time Anthropic changes its prices.
- A new menu item or setting needs a change in the README tables.
