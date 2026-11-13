#!/bin/bash
# ProPre2.0 launcher for Mac.
# Uses only what is already built into macOS (Perl and curl) - nothing to download or install.
cd "$(dirname "$0")" || exit 1

PORT=3000
BASE="http://localhost:$PORT"
# A profile of its own: Chrome hands a new launch to an already-running instance that uses the same profile,
# and that instance ignores the window position, so the output must not share a profile with older windows.
PROFILE="$HOME/propre-output-profile-main"

running() { curl -s -m 1 -o /dev/null "$BASE/api/live"; }

# Prints "x y w h" for the first display that is not the built-in laptop screen, in the top-left-origin
# coordinates Chrome uses for --window-position. Prints nothing if only the laptop screen is connected.
# The main display (the one with the menu bar) can be the external monitor, so the laptop is found by name.
extended_display() {
  osascript -l JavaScript -e '
    ObjC.import("AppKit");
    const screens = $.NSScreen.screens;
    const main = screens.objectAtIndex(0).frame;
    let out = "";
    for (let i = 0; i < screens.count; i++) {
      const screen = screens.objectAtIndex(i);
      // CGDisplayIsBuiltin is true for the laptop screen whatever language macOS is set to
      const id = ObjC.unwrap(screen.deviceDescription.objectForKey("NSScreenNumber"));
      if ($.CGDisplayIsBuiltin(id)) continue;
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
  geom="$(extended_display)"
  echo "Extended display found: ${geom:-none (only the main screen is connected)}"
  for app in "Google Chrome" "Microsoft Edge" "Brave Browser"; do
    exe="/Applications/$app.app/Contents/MacOS/$app"
    if [ -x "$exe" ]; then
      if [ -n "$geom" ]; then
        read -r x y w h <<< "$geom"
        nohup "$exe" --kiosk --user-data-dir="$PROFILE" --no-first-run \
          --window-position="$x,$y" --window-size="$w,$h" "$url" >/dev/null 2>&1 &
        # Wait for the output window itself (found by its address), then move it onto the extended display
        placed=""; err=""; errfile="$(mktemp)"
        for i in $(seq 1 75); do
          placed="$(osascript -e "tell application \"$app\"
            repeat with win in windows
              if (URL of active tab of win) contains \"output.html\" then
                set bounds of win to {$x, $y, $((x + w)), $((y + h))}
                return \"placed\"
              end if
            end repeat
            return \"waiting\"
          end tell" 2>"$errfile")"
          [ "$placed" = "placed" ] && break
          sleep 0.4
        done
        if [ "$placed" = "placed" ]; then
          echo "Output opened in $app on the extended display."
        else
          echo "Output opened in $app, but it could not be moved to the extended display."
          err="$(cat "$errfile" 2>/dev/null)"; rm -f "$errfile"
          [ -n "$err" ] && echo "  macOS said: $err"
          echo "  Windows $app has open (their current addresses):"
          osascript -e "tell application \"$app\" to get URL of active tab of windows" 2>&1 | sed 's/^/    /'
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

open "$BASE/index.html"
open_output "$BASE/output.html"
exit 0
