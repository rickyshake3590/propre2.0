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
  # Use logo.png from this folder as the app icon (a square image, 1024 x 1024 pixels is best)
  LOGO="$PROJECT/logo.png"
  if [ -f "$LOGO" ]; then
    ICONSET="$(mktemp -d -t propre-icon)/applet.iconset"
    mkdir -p "$ICONSET"
    for s in 16 32 128 256 512; do
      sips -z $s $s "$LOGO" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
      sips -z $((s * 2)) $((s * 2)) "$LOGO" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    # Remove the default icon data that macOS would otherwise show instead of the new icon
    rm -f "$APP/Contents/Resources/Assets.car"
    if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/applet.icns"; then
      touch "$APP"
      echo "Logo applied from logo.png."
    else
      echo "Could not make the icon from logo.png. The default icon is used."
    fi
    rm -rf "$(dirname "$ICONSET")"
  else
    echo "No logo.png in this folder. The app uses the default icon."
  fi
  echo "Open it to start ProPre2.0. Choose Quit to stop it."
else
  echo "Could not create the app. See the error above."
fi
rm -f "$SRC"
read -r -p "Press Enter to close..."
