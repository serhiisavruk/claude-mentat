#!/bin/bash
# Mentat installer. Builds the app from source with swiftc and installs it for the current user.
#   bash install.sh            install or update
#   bash install.sh uninstall  remove
# Blocks between ">>>" and "<<<" markers are replaced by build-installer.py to make the prebuilt installer.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="$HOME/.config/mentat"
PLIST="$HOME/Library/LaunchAgents/com.mentat.plist"
LABEL="com.mentat"

stop_app() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  pkill -x Mentat 2>/dev/null || true
}

if [ "${1:-}" = "uninstall" ]; then
  stop_app
  rm -f "$PLIST"
  rm -rf "$DIR" "$HOME/Library/Logs/Mentat"
  echo "Mentat removed."
  exit 0
fi

[ "$(uname -s)" = "Darwin" ] || { echo "Mentat needs macOS."; exit 1; }
# >>> checks
# <<< checks
# >>> version
VERSION="$(sed -n 's/^let appVersion = "\(.*\)"/\1/p' "$HERE/Mentat.swift")"
# <<< version

mkdir -p "$DIR"
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
"$DIR/Mentat" --print >/dev/null || { echo "Mentat did not start. Please report this."; exit 1; }
echo "$VERSION" > "$DIR/VERSION"

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/Mentat"
cat > "$PLIST" <<MENTAT_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$DIR/Mentat</string></array>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$HOME/Library/Logs/Mentat/launchd.log</string>
<key>StandardErrorPath</key><string>$HOME/Library/Logs/Mentat/launchd.log</string>
</dict></plist>
MENTAT_PLIST

if [ -z "${MENTAT_NO_LAUNCH:-}" ]; then
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "Mentat $VERSION is running. Look at the menu bar. It starts at login."
else
  echo "Installed. Launch skipped."
fi
