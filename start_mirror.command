#!/bin/bash
# Second computer (E2): shows exactly what the main computer (E1) is showing, fullscreen.
# Nothing runs here except the browser window. Start ProPre2.0 on E1 first.
# To close the window, run stop_propre.command on this computer.
cd "$(dirname "$0")" || exit 1

# The address of the main computer (E1). It is shown at the top of the E1 dashboard.
# Usually the computer's name with .local on the end, e.g. "E1.local",
# or a number like "169.254.10.5" if that name doesn't work.
E1_ADDRESS="E1.local"

PORT=3000
ADDRESS="${1:-$E1_ADDRESS}"
BASE="http://$ADDRESS:$PORT"
PROFILE="$HOME/propre-output-profile"

open_output() {
  local url="$1" app exe
  for app in "Google Chrome" "Microsoft Edge" "Brave Browser"; do
    exe="/Applications/$app.app/Contents/MacOS/$app"
    if [ -x "$exe" ]; then
      nohup "$exe" --kiosk --user-data-dir="$PROFILE" --no-first-run "$url" >/dev/null 2>&1 &
      echo "Mirrored output opened fullscreen in $app."
      return 0
    fi
  done
  if [ -x "/Applications/Firefox.app/Contents/MacOS/firefox" ]; then
    nohup /Applications/Firefox.app/Contents/MacOS/firefox -kiosk "$url" >/dev/null 2>&1 &
    echo "Mirrored output opened fullscreen in Firefox."
    return 0
  fi
  open -a Safari "$url"
  sleep 2
  osascript -e 'tell application "System Events" to keystroke "f" using {command down, control down}' >/dev/null 2>&1
  echo "Mirrored output opened in Safari. If it is not fullscreen, press Ctrl+Cmd+F."
}

echo "Looking for ProPre2.0 on $ADDRESS ..."
found=0
for i in $(seq 1 10); do
  if curl -s -m 3 -o /dev/null "$BASE/api/live"; then found=1; break; fi
  sleep 2
done
if [ "$found" -ne 1 ]; then
  echo "Could not reach $ADDRESS."
  echo "Check that ProPre2.0 is running on E1, the ethernet cable is connected,"
  echo "and E1_ADDRESS in start_mirror.command matches the address shown on the E1 dashboard."
  read -r -p "Press Enter to close..."
  exit 1
fi
open_output "$BASE/output.html"
exit 0
