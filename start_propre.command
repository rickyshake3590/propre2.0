#!/bin/bash
# ProPre2.0 launcher for Mac.
# Uses only what is already built into macOS (Perl and curl) - nothing to download or install.
cd "$(dirname "$0")" || exit 1

PORT=3000
BASE="http://localhost:$PORT"
PROFILE="$HOME/propre-output-profile"

running() { curl -s -m 1 -o /dev/null "$BASE/api/live"; }

# Opens the output screen fullscreen in a browser that supports kiosk mode (Chrome, Edge, Brave, Firefox),
# otherwise in Safari fullscreen.
open_output() {
  local url="$1" app exe
  for app in "Google Chrome" "Microsoft Edge" "Brave Browser"; do
    exe="/Applications/$app.app/Contents/MacOS/$app"
    if [ -x "$exe" ]; then
      nohup "$exe" --kiosk --user-data-dir="$PROFILE" --no-first-run "$url" >/dev/null 2>&1 &
      echo "Output opened fullscreen in $app."
      return 0
    fi
  done
  if [ -x "/Applications/Firefox.app/Contents/MacOS/firefox" ]; then
    nohup /Applications/Firefox.app/Contents/MacOS/firefox -kiosk "$url" >/dev/null 2>&1 &
    echo "Output opened fullscreen in Firefox."
    return 0
  fi
  open -a Safari "$url"
  sleep 2
  osascript -e 'tell application "System Events" to keystroke "f" using {command down, control down}' >/dev/null 2>&1
  echo "Output opened in Safari. If it is not fullscreen, press Ctrl+Cmd+F."
}

if running; then
  echo "ProPre2.0 is already running."
else
  nohup /usr/bin/perl server.pl >> server.log 2>&1 &
  for i in $(seq 1 50); do
    running && break
    sleep 0.2
  done
  if ! running; then
    echo "The server did not start. See server.log in this folder for details."
    read -r -p "Press Enter to close..."
    exit 1
  fi
  echo "ProPre2.0 started."
fi

open "$BASE/index.html"
open_output "$BASE/output.html"
exit 0
