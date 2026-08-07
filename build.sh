#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

BIN="$(swift build -c release --show-bin-path)/SpaceTab"
APP="build/SpaceTab.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SpaceTab"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Regenerate from the SF Symbol if missing, so a fresh clone still gets an icon.
if [ ! -f Resources/AppIcon.icns ]; then
    swift Tools/makeicon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

SIGN_ID="${SPACETAB_SIGN_ID:--}"
codesign --force --sign "$SIGN_ID" "$APP"

# An ad-hoc signature binds TCC's Accessibility grant to the cdhash, which
# changes on every build. The old grant survives in the UI as a checked box that
# authorises a binary no longer on disk, and re-toggling it just re-grants that
# stale record. Clearing it forces a fresh, correct prompt.
if [ "$SIGN_ID" = "-" ]; then
    tccutil reset Accessibility com.mp.spacetab >/dev/null 2>&1 || true
    echo "Ad-hoc signed: Accessibility permission reset, grant once on launch."
else
    echo "Signed with '$SIGN_ID': Accessibility permission persists across builds."
fi

echo "Built $APP"
