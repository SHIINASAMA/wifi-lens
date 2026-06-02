#!/bin/bash
set -euo pipefail

# ============================================================
# create-dmg.sh — Create a styled DMG for WiFi Lens
#
# Usage:
#   ./scripts/create-dmg.sh <app-path> [output-dmg-path]
#
# Dependencies:
#   brew install create-dmg   (one-time setup)
#   Background image at assets/dmg-background.png
# ============================================================

APP_PATH="${1:?Usage: $0 <app-path> [output-dmg-path]}"
APP_NAME=$(basename "$APP_PATH" .app)
OUTPUT="${2:-$APP_NAME.dmg}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKGROUND="$SCRIPT_DIR/../assets/dmg-background.png"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found"
    exit 1
fi

if [ ! -f "$BACKGROUND" ]; then
    echo "Error: background image not found at $BACKGROUND"
    exit 1
fi

# Ensure create-dmg (the shell-based one from Homebrew) is available
if ! command -v create-dmg &>/dev/null; then
    echo "Installing create-dmg via Homebrew..."
    brew install create-dmg
fi

# create-dmg reads files from a source folder, so copy the .app into a
# clean staging directory to avoid picking up stray files.
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$APP_PATH" "$STAGING_DIR/"
# Purge all hidden files that would confuse create-dmg's icon layout
find "$STAGING_DIR" \( -name '.DS_Store' -o -name '.background' -o -name '.fseventsd' -o -name '.Trashes' \) -prune -exec rm -rf {} + 2>/dev/null || true

echo "Creating DMG for $APP_NAME..."
echo "  App:        $APP_PATH"
echo "  Background: $BACKGROUND"
echo "  Output:     $OUTPUT"

create-dmg \
    --volname "$APP_NAME" \
    --background "$BACKGROUND" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 180 170 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 480 170 \
    --icon ".background" 200 190 \
    "$OUTPUT" \
    "$STAGING_DIR/"

echo "Done: $OUTPUT"
