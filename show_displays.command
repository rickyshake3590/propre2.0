#!/bin/bash
# Shows every connected screen and which one ProPre2.0 will use for the output window.
# Double-click this file, or run it in Terminal. Nothing is changed.

osascript -l JavaScript <<'JXA'
ObjC.import("AppKit");
const screens = $.NSScreen.screens;
const main = screens.objectAtIndex(0).frame;
const lines = [];
lines.push("Connected screens: " + screens.count);
lines.push("");

let chosen = -1;
for (let i = 0; i < screens.count; i++) {
  const screen = screens.objectAtIndex(i);
  const f = screen.frame;
  const id = ObjC.unwrap(screen.deviceDescription.objectForKey("NSScreenNumber"));
  const builtin = !!$.CGDisplayIsBuiltin(id);
  const name = ObjC.unwrap(screen.localizedName);
  // Same rule as start_propre.command: the first screen that is not the built-in laptop screen
  if (chosen < 0 && !builtin) chosen = i;
  // Chrome's position uses the top-left corner of the main screen as (0, 0)
  const topLeftY = Math.round(main.size.height - (f.origin.y + f.size.height));
  lines.push("Screen " + i + ": " + name);
  lines.push("   Built-in laptop screen: " + (builtin ? "yes" : "no"));
  lines.push("   Main screen (menu bar): " + (i === 0 ? "yes" : "no"));
  lines.push("   Size: " + Math.round(f.size.width) + " x " + Math.round(f.size.height) + " points");
  lines.push("   Position for Chrome: x=" + Math.round(f.origin.x) + ", y=" + topLeftY);
  lines.push("");
}

if (chosen < 0) {
  lines.push("ProPre2.0 will use: the main screen (no screen other than the built-in one is connected)");
} else {
  const screen = screens.objectAtIndex(chosen);
  const f = screen.frame;
  const topLeftY = Math.round(main.size.height - (f.origin.y + f.size.height));
  lines.push("ProPre2.0 will put the output window on: Screen " + chosen + " - " + ObjC.unwrap(screen.localizedName));
  lines.push("   at x=" + Math.round(f.origin.x) + ", y=" + topLeftY + ", size " + Math.round(f.size.width) + " x " + Math.round(f.size.height));
}
lines.join("\n");
JXA

echo ""
read -r -p "Press Enter to close..."
