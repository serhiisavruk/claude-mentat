#!/usr/bin/env python3
"""Build install-prebuilt.sh: the same installer as install.sh, with a compiled arm64 binary and the default
config inside. Users need no Xcode. Needs swiftc on THIS Mac. Output is not committed; CI attaches it to releases."""
import base64, gzip, os, re, subprocess, sys, tempfile
here = os.path.dirname(os.path.abspath(__file__))
MIN_MACOS = 12
swift = open(os.path.join(here, "Mentat.swift")).read()
VERSION = re.search(r'let appVersion = "([^"]+)"', swift).group(1)
if "--version" in sys.argv:
    print(VERSION)
    sys.exit()

with tempfile.TemporaryDirectory() as tmp:
    exe = os.path.join(tmp, "Mentat")
    subprocess.run(["swiftc", "-O", "-target", f"arm64-apple-macos{MIN_MACOS}",
                    os.path.join(here, "Mentat.swift"), "-o", exe], check=True)
    blob = base64.encodebytes(gzip.compress(open(exe, "rb").read(), 9)).decode()
config = open(os.path.join(here, "config.json")).read()

blocks = {
    "checks": f'''[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] || {{ echo "This prebuilt installer needs a Mac with Apple Silicon. Build from source instead: bash install.sh"; exit 1; }}
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge {MIN_MACOS} ] || {{ echo "Mentat needs macOS {MIN_MACOS} or newer."; exit 1; }}
''',
    "version": f'VERSION="{VERSION}"\n',
    "config": f'''if [ ! -f "$DIR/config.json" ]; then
cat > "$DIR/config.json" <<'MENTAT_CONFIG'
{config}MENTAT_CONFIG
fi
''',
    "binary": f'''base64 -D <<'MENTAT_BINARY' | gunzip > "$DIR/Mentat.tmp"
{blob}MENTAT_BINARY
''',
}

script = open(os.path.join(here, "install.sh")).read()
for name, body in blocks.items():
    pattern = re.compile(rf"# >>> {name}\n.*?# <<< {name}\n", re.S)
    if not pattern.search(script):
        sys.exit(f"marker block '{name}' not found in install.sh")
    script = pattern.sub(lambda m: body, script, count=1)
script = script.replace('HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\n', "")
script = script.replace(
    "# Mentat installer. Builds the app from source with swiftc and installs it for the current user.",
    f"# Mentat {VERSION} prebuilt installer (Apple Silicon, macOS {MIN_MACOS}+). Generated from install.sh. No Xcode needed.")
script = re.sub(r"# Blocks between.*\n", "", script)
script = script.replace("#   bash install.sh            install or update\n#   bash install.sh uninstall  remove\n",
                        "#   curl -fsSL <release URL>/install-prebuilt.sh | bash   install or update\n"
                        "#   mentat uninstall                                      remove\n")
out = os.path.join(here, "install-prebuilt.sh")
open(out, "w").write(script)
print("wrote install-prebuilt.sh", len(script) // 1024, "KB")
