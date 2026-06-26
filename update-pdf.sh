#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INPUT="$SCRIPT_DIR/index.html"
OUTPUT="$SCRIPT_DIR/Pablo Terradillos - Resume.pdf"

if [ "${CHROME:-}" ]; then
  CHROME_BIN=$CHROME
elif command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN=$(command -v google-chrome)
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN=$(command -v chromium)
elif command -v chromium-browser >/dev/null 2>&1; then
  CHROME_BIN=$(command -v chromium-browser)
elif [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
  CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
else
  echo "Google Chrome or Chromium is required to regenerate the PDF" >&2
  echo "On macOS, install it with: brew install --cask google-chrome" >&2
  exit 1
fi

if [ ! -x "$CHROME_BIN" ]; then
  echo "Chrome was not found or is not executable at: $CHROME_BIN" >&2
  exit 1
fi

"$CHROME_BIN" \
  --headless \
  --disable-gpu \
  --no-sandbox \
  --no-pdf-header-footer \
  --print-to-pdf="$OUTPUT" \
  "file://$INPUT"

echo "Updated $OUTPUT"
