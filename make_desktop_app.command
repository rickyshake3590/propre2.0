#!/bin/bash
# Builds the ProPre2.0 app icon on the Desktop.
# Run this once (double-click it). After that, open ProPre2.0 from the Desktop to start, and Quit to stop.
cd "$(dirname "$0")" || exit 1
PROJECT="$PWD"
APP="$HOME/Desktop/ProPre2.0.app"
SRC="$(mktemp -t propre-app).applescript"

sed "s|__PROJECT__|$PROJECT|" ProPre2.0.applescript > "$SRC"
if osacompile -o "$APP" "$SRC"; then
  echo "Created $APP"
  echo "Open it to start ProPre2.0. Choose Quit to stop it."
else
  echo "Could not create the app. See the error above."
fi
rm -f "$SRC"
read -r -p "Press Enter to close..."
