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

# Control command: ~/.config/mentat/mentatctl start|stop|restart|status|uninstall
cat > "$DIR/mentatctl" <<'MENTAT_CTL'
#!/bin/bash
# Control Mentat. Usage: mentatctl [start|stop|restart|status|uninstall]
set -euo pipefail
DIR="$HOME/.config/mentat"
PLIST="$HOME/Library/LaunchAgents/com.mentat.plist"
LABEL="com.mentat"
DOMAIN="gui/$(id -u)"
LOGS="$HOME/Library/Logs/Mentat"

running() { pgrep -u "$(id -u)" -x Mentat >/dev/null 2>&1; }
loaded() { launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; }

wait_for() { # wait_for up|down
  for _ in $(seq 1 20); do
    if [ "$1" = up ] && running; then return 0; fi
    if [ "$1" = down ] && ! running; then return 0; fi
    sleep 0.25
  done
  return 1
}

start() {
  if running; then echo "Mentat is already running."; return; fi
  [ -x "$DIR/Mentat" ] || { echo "Mentat is not installed."; exit 1; }
  if loaded; then
    launchctl kickstart "$DOMAIN/$LABEL" 2>/dev/null || true
  elif [ -f "$PLIST" ]; then
    launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null || true
  fi
  # No login item, or launchd refused: start the app directly.
  if ! wait_for up; then
    mkdir -p "$LOGS"
    nohup "$DIR/Mentat" </dev/null >>"$LOGS/launchd.log" 2>&1 &
  fi
  if wait_for up; then echo "Mentat started."
  else echo "Mentat did not start. See the logs in $LOGS (mentat.log, launchd.log)."; exit 1; fi
}

stop() {
  if ! running; then echo "Mentat is not running."; return; fi
  pkill -u "$(id -u)" -x Mentat || true
  if ! wait_for down; then pkill -9 -u "$(id -u)" -x Mentat || true; wait_for down || true; fi
  if running; then echo "Mentat did not stop."; exit 1; fi
  echo "Mentat stopped."
}

status() {
  local v; v="$(cat "$DIR/VERSION" 2>/dev/null || echo "?")"
  if running; then echo "Mentat $v: running (pid $(pgrep -u "$(id -u)" -x Mentat | head -1))"; else echo "Mentat $v: not running"; fi
  if [ -f "$PLIST" ]; then echo "Start at login: on"; else echo "Start at login: off"; fi
  echo "App:        $DIR/Mentat"
  echo "Settings:   $DIR/config.json"
  echo "Log:        $LOGS/mentat.log"
  echo "Login item: $PLIST"
}

uninstall() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  pkill -u "$(id -u)" -x Mentat 2>/dev/null || true
  rm -f "$PLIST"
  rm -rf "$DIR" "$LOGS"
  echo "Mentat removed."
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  uninstall) uninstall ;;
  *) echo "Usage: mentatctl [start|stop|restart|status|uninstall]"; exit 2 ;;
esac
MENTAT_CTL
chmod +x "$DIR/mentatctl"

if [ "$LOGIN" = on ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<MENTAT_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$LABEL</string>
<key>ProgramArguments</key><array><string>$DIR/Mentat</string></array>
<key>RunAtLoad</key><true/>
<key>StandardOutPath</key><string>$LOGS/launchd.log</string>
<key>StandardErrorPath</key><string>$LOGS/launchd.log</string>
</dict></plist>
MENTAT_PLIST
fi

if [ -n "${MENTAT_NO_LAUNCH:-}" ]; then
  echo "Installed. Launch skipped."
else
  "$DIR/mentatctl" start >/dev/null || { echo "Installed, but Mentat did not start. See the logs in $LOGS"; exit 1; }
  echo "Mentat $VERSION is running. Look at the menu bar."
  if [ "$LOGIN" = on ]; then echo "It starts at login."; else echo "Start at login stays off, as you set it."; fi
fi
echo "Control it with: ~/.config/mentat/mentatctl start|stop|restart|status|uninstall"
}

main "$@"
