#!/bin/bash
# ProPre2.0 launcher for Mac.
# Uses only what is already built into macOS (Perl and curl) - nothing to download or install.
cd "$(dirname "$0")" || exit 1

PORT="${PROPRE_PORT:-3000}"
BASE="http://localhost:$PORT"
# A profile of its own: Chrome hands a new launch to an already-running instance that uses the same profile,
# and that instance ignores the window position, so the output must not share a profile with older windows.
# Which screen the output window goes to. Leave it empty to use the first screen that is not the laptop screen.
# To pick a screen by its name (run show_displays.command to see the names), type the name, e.g. "BMD HDMI".
OUTPUT_DISPLAY=""

running() { curl -s -m 1 -o /dev/null "$BASE/api/live"; }

# Prints "x y w h" of the chosen screen, in the top-left-origin coordinates Chrome uses for --window-position.
# With a name given, prints the screen with that name. Without one, prints the first screen that is not the
# built-in laptop screen. Prints nothing if no such screen is connected.
# The main display (the one with the menu bar) can be the external monitor, so the laptop is found by its flag.
extended_display() {
  PROPRE_OUTPUT_DISPLAY="$1" osascript -l JavaScript -e '
    ObjC.import("AppKit");
    const want = ObjC.unwrap($.NSProcessInfo.processInfo.environment.objectForKey("PROPRE_OUTPUT_DISPLAY")) || "";
    const screens = $.NSScreen.screens;
    const main = screens.objectAtIndex(0).frame;
    let out = "";
    for (let i = 0; i < screens.count; i++) {
      const screen = screens.objectAtIndex(i);
      // CGDisplayIsBuiltin is true for the laptop screen whatever language macOS is set to
      const id = ObjC.unwrap(screen.deviceDescription.objectForKey("NSScreenNumber"));
      const name = ObjC.unwrap(screen.localizedName);
      if (want ? name !== want : $.CGDisplayIsBuiltin(id)) continue;
      const f = screen.frame;
      const x = Math.round(f.origin.x);
      const y = Math.round(main.size.height - (f.origin.y + f.size.height));
      out = [x, y, Math.round(f.size.width), Math.round(f.size.height)].join(" ");
      break;
    }
    out;' 2>/dev/null
}

# Opens the output screen fullscreen in a browser that supports kiosk mode (Chrome, Edge, Brave, Firefox),
# otherwise in Safari fullscreen. If an extended display is connected, the Chromium-based browsers
# open on that display, filling it, instead of on the main screen.
open_output() {
  local url="$1" app exe geom="" x y w h
  geom="$(extended_display "$OUTPUT_DISPLAY")"
  if [ -n "$OUTPUT_DISPLAY" ] && [ -z "$geom" ]; then
    echo "No screen named \"$OUTPUT_DISPLAY\" is connected. Using the first other screen instead."
    geom="$(extended_display "")"
  fi
  echo "Output screen: ${geom:-none (only the built-in laptop screen is connected)}"
  for app in "Google Chrome" "Microsoft Edge" "Brave Browser"; do
    exe="/Applications/$app.app/Contents/MacOS/$app"
    if [ -x "$exe" ]; then
      if [ -n "$geom" ]; then
        read -r x y w h <<< "$geom"
        # Close an output window left from an earlier run, so the new one is the only output window
        osascript -e "if application \"$app\" is running then tell application \"$app\" to close (every window whose URL of active tab contains \"output.html\")" >/dev/null 2>&1
        sleep 1
        # A new profile for every launch, so Chrome never hands this launch to an older window
        PROFILE="$(mktemp -d "${TMPDIR:-/tmp}/propre-output.XXXXXX")"
        # Kiosk mode is not used: Chrome moves a kiosk window to the main screen and ignores the position,
        # and a full-screen window cannot be moved afterwards. A plain app window can be placed exactly.
        nohup "$exe" --app="$url" --user-data-dir="$PROFILE" --no-first-run >/dev/null 2>&1 &
        # Place the output window by its address, then read its position back to check it is on the chosen screen
        got=""; bx=""; by=""; br=""; bb=""
        for i in $(seq 1 75); do
          got="$(osascript -e "tell application \"$app\"
            repeat with win in windows
              if (URL of active tab of win) contains \"output.html\" then
                set bounds of win to {$x, $y, $((x + w)), $((y + h))}
                set b to bounds of win
                return (item 1 of b as text) & \", \" & (item 2 of b as text) & \", \" & (item 3 of b as text) & \", \" & (item 4 of b as text)
              end if
            end repeat
            return \"none\"
          end tell" 2>/dev/null)"
          if [ "$got" != "none" ] && [ -n "$got" ]; then
            IFS=', ' read -r bx by br bb <<< "$got"
            if [ "$bx" -ge "$x" ] && [ "$bx" -lt $((x + w)) ]; then break; fi
          fi
          sleep 0.4
        done
        if [ -n "$bx" ] && [ "$bx" -ge "$x" ] && [ "$bx" -lt $((x + w)) ]; then
          echo "Output opened in $app on the chosen screen (window at x=$bx, y=$by, right $br, bottom $bb)."
        else
          echo "Output opened in $app, but it is not on the chosen screen. Window reported at: ${got:-no window found}"
          echo "  Chosen screen: x=$x, y=$y, size $w x $h"
          echo "  Allow Terminal to control $app: System Settings > Privacy & Security > Automation."
        fi
      else
        nohup "$exe" --kiosk --user-data-dir="$PROFILE" --no-first-run "$url" >/dev/null 2>&1 &
        echo "Output opened fullscreen in $app."
      fi
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

# Keep an eye on the server: if the Mac sleeps or shuts down, ProPre2.0 stops by itself
WATCH_PIDFILE="$PWD/.propre-watch.pid"
if ! { [ -f "$WATCH_PIDFILE" ] && kill -0 "$(cat "$WATCH_PIDFILE")" 2>/dev/null; }; then
  PROPRE_PORT="$PORT" nohup /bin/bash "$PWD/watch_propre.sh" >/dev/null 2>&1 </dev/null &
fi

open "$BASE/index.html"
open_output "$BASE/output.html"
exit 0
