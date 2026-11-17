#!/bin/bash
# Mentat installer. Builds the app from source with swiftc and installs it for the current user.
#   bash install.sh            install or update
#   bash install.sh uninstall  remove
# Blocks between ">>>" and "<<<" markers are replaced by build-installer.py to make the prebuilt installer.
# The whole script is one function, called on the last line. Bash reads all of it before it runs anything,
# so `curl ... | bash` is safe: no command can read the rest of the script from stdin.
set -euo pipefail

main() {
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$HOME/.config/mentat"
PLIST="$HOME/Library/LaunchAgents/com.mentat.plist"
LABEL="com.mentat"
DOMAIN="gui/$(id -u)"
LOGS="$HOME/Library/Logs/Mentat"

running() { pgrep -u "$(id -u)" -x Mentat >/dev/null 2>&1; }
loaded() { launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; }

# Stop the app and unload the login item. Wait until both are gone: a bootstrap right after
# bootout can fail with "Bootstrap failed: 5" while launchd is still removing the old job.
stop_app() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  pkill -u "$(id -u)" -x Mentat 2>/dev/null || true
  for _ in $(seq 1 40); do
    if ! loaded && ! running; then return 0; fi
    sleep 0.25
  done
  pkill -9 -u "$(id -u)" -x Mentat 2>/dev/null || true
}

if [ "${1:-}" = "uninstall" ]; then
  stop_app
  rm -f "$PLIST"
  if [[ "$(readlink "$HOME/.local/bin/mentat" 2>/dev/null)" == "$DIR/"* ]]; then rm -f "$HOME/.local/bin/mentat"; fi
  rm -rf "$DIR" "$LOGS"
  echo "Mentat removed."
  exit 0
fi

[ "$(uname -s)" = "Darwin" ] || { echo "Mentat needs macOS."; exit 1; }
# >>> checks
# <<< checks
# >>> version
VERSION="$(sed -n 's/^let appVersion = "\(.*\)"/\1/p' "$HERE/Mentat.swift")"
# <<< version

PATH_HINT=""
MENTAT_CMD="mentat"
# An update keeps the user's choice: if Start at login was turned off, leave it off.
LOGIN=on
if [ -f "$DIR/VERSION" ] && [ ! -f "$PLIST" ]; then LOGIN=off; fi

mkdir -p "$DIR" "$LOGS"
rm -f "$DIR/usage.py"
rm -rf "$DIR/src"

# Keep the user's own settings when updating.
# >>> config
if [ ! -f "$DIR/config.json" ]; then
  cp "$HERE/config.json" "$DIR/config.json"
fi
# <<< config

if [ -z "${MENTAT_NO_LAUNCH:-}" ]; then stop_app; fi
# >>> binary
if ! command -v swiftc >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
  echo "swiftc not found. Install the Xcode Command Line Tools first:  xcode-select --install"
  echo "Then run this script again."
  exit 1
fi
echo "Building Mentat $VERSION from source..."
swiftc -O "$HERE/Mentat.swift" -o "$DIR/Mentat.tmp"
# <<< binary
chmod +x "$DIR/Mentat.tmp"
mv -f "$DIR/Mentat.tmp" "$DIR/Mentat"
xattr -d com.apple.quarantine "$DIR/Mentat" 2>/dev/null || true
codesign --force --sign - "$DIR/Mentat" 2>/dev/null || true
"$DIR/Mentat" --print >/dev/null </dev/null || { echo "Mentat did not start. Please report this."; exit 1; }
echo "$VERSION" > "$DIR/VERSION"

rm -f "$DIR/mentatctl" # replaced by the "mentat" command in 2.0.1

# The "mentat" command: a link in ~/.local/bin (the same folder Claude Code's installer uses).
# Never replace a different program that is already called "mentat".
LINK="$HOME/.local/bin/mentat"
mkdir -p "$HOME/.local/bin"
if [ ! -e "$LINK" ] && [ ! -L "$LINK" ] || [[ "$(readlink "$LINK" 2>/dev/null)" == "$DIR/"* ]]; then
  ln -sfn "$DIR/Mentat" "$LINK"
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH_HINT=1 ;; esac
else
  echo "Note: $LINK already exists and is not Mentat. Left it alone."
  MENTAT_CMD="$DIR/Mentat"
fi

if [ "$LOGIN" = on ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<MENTAT_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$DIR/Mentat</string><string>run</string></array>
<key>RunAtLoad</key><true/>
<key>EnvironmentVariables</key><dict><key>HOME</key><string>$HOME</string></dict>
<key>StandardOutPath</key><string>$LOGS/launchd.log</string>
<key>StandardErrorPath</key><string>$LOGS/launchd.log</string>
</dict></plist>
MENTAT_PLIST
fi

if [ -n "${MENTAT_NO_LAUNCH:-}" ]; then
  echo "Installed. Launch skipped."
else
  "$DIR/Mentat" start >/dev/null || { echo "Installed, but Mentat did not start. See the logs in $LOGS"; exit 1; }
  echo "Mentat $VERSION is running. Look at the menu bar."
  if [ "$LOGIN" = on ]; then echo "It starts at login."; else echo "Start at login stays off, as you set it."; fi
fi
echo "Control it with: $MENTAT_CMD status|start|stop|restart|uninstall"
if [ -n "$PATH_HINT" ]; then
  echo "To use the short name, add ~/.local/bin to your PATH:"
  echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi
}

main "$@"
