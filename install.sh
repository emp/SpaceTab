#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

DEST="/Applications/SpaceTab.app"

if pgrep -x SpaceTab >/dev/null; then
    echo "Stopping running instance…"
    pkill -x SpaceTab
    sleep 1
fi

rm -rf "$DEST"
cp -R build/SpaceTab.app "$DEST"

# TCC records the path alongside the signature, so the copy is a different app
# as far as Accessibility is concerned. Clear it and grant once at the new home.
tccutil reset Accessibility com.mp.spacetab >/dev/null 2>&1 || true

echo "Installed $DEST"
echo "Launching — grant Accessibility when System Settings opens."
open "$DEST"
