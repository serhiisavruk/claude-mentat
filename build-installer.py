#!/usr/bin/env python3
"""Build install.sh: one self-contained file with the compiled Mentat binary (gzip+base64) and the default config.
Needs Xcode tools on THIS Mac only. End users need nothing."""
import base64, gzip, os, re, subprocess, sys, tempfile
here = os.path.dirname(os.path.abspath(__file__))
VERSION = re.search(r'let appVersion = "([^"]+)"', open(os.path.join(here, "Mentat.swift")).read()).group(1)
MIN_MACOS = 12
if "--version" in sys.argv:
    print(VERSION)
    sys.exit()

with tempfile.TemporaryDirectory() as tmp:
    exe = os.path.join(tmp, "Mentat")
    subprocess.run(["swiftc", "-O", "-target", f"arm64-apple-macos{MIN_MACOS}",
                    os.path.join(here, "Mentat.swift"), "-o", exe], check=True)
    blob = base64.encodebytes(gzip.compress(open(exe, "rb").read(), 9)).decode()
config = open(os.path.join(here, "config.json")).read()

out = f'''#!/bin/bash
# Mentat {VERSION} installer: Claude Code cost in the macOS menu bar (Apple Silicon, macOS {MIN_MACOS}+).
# Nothing else to install.
# Usage:  bash install.sh            install or update
#         bash install.sh uninstall  remove
set -euo pipefail
DIR="$HOME/.config/mentat"
PLIST="$HOME/Library/LaunchAgents/com.mentat.plist"
LABEL="com.mentat"

stop_app() {{
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  pkill -x Mentat 2>/dev/null || true
}}

if [ "${{1:-}}" = "uninstall" ]; then
  stop_app
  rm -f "$PLIST"
  rm -rf "$DIR" "$HOME/Library/Logs/Mentat"
  echo "Mentat removed."
  exit 0
fi

[ "$(uname -s)" = "Darwin" ] || {{ echo "Mentat needs macOS."; exit 1; }}
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] || {{ echo "Mentat needs a Mac with Apple Silicon."; exit 1; }}
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge {MIN_MACOS} ] || {{ echo "Mentat needs macOS {MIN_MACOS} or newer."; exit 1; }}

mkdir -p "$DIR"
rm -f "$DIR/usage.py"
rm -rf "$DIR/src"

# Keep the user's own settings when updating.
if [ ! -f "$DIR/config.json" ]; then
cat > "$DIR/config.json" <<'MENTAT_CONFIG'
{config}MENTAT_CONFIG
fi

if [ -z "${{MENTAT_NO_LAUNCH:-}}" ]; then stop_app; fi
base64 -D <<'MENTAT_BINARY' | gunzip > "$DIR/Mentat.tmp"
{blob}MENTAT_BINARY
chmod +x "$DIR/Mentat.tmp"
mv -f "$DIR/Mentat.tmp" "$DIR/Mentat"
xattr -d com.apple.quarantine "$DIR/Mentat" 2>/dev/null || true
codesign --force --sign - "$DIR/Mentat" 2>/dev/null || true
"$DIR/Mentat" --print >/dev/null || {{ echo "Mentat did not start. Please report this."; exit 1; }}
echo "{VERSION}" > "$DIR/VERSION"

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

if [ -z "${{MENTAT_NO_LAUNCH:-}}" ]; then
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "Mentat {VERSION} is running. Look at the menu bar. It starts at login."
else
  echo "Installed. Launch skipped."
fi
'''
open(os.path.join(here, "install.sh"), "w").write(out)
print("wrote install.sh", len(out) // 1024, "KB,", len(out.splitlines()), "lines")
