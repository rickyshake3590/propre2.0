#!/bin/bash
# Stops ProPre2.0 by itself when the Mac sleeps or shuts down.
# Started in the background by start_propre.command. Exits on its own when the server stops.
cd "$(dirname "$0")" || exit 1

PORT="${PROPRE_PORT:-3000}"
BASE="http://localhost:$PORT"
PIDFILE="$PWD/.propre-watch.pid"
# The loop wakes every 2 seconds. If the clock has moved on by more than this, the Mac was asleep.
GAP=20

running() { curl -s -m 1 -o /dev/null "$BASE/api/live"; }

stop_all() {
  PROPRE_PORT="$PORT" /bin/bash "$PWD/stop_propre.command" >/dev/null 2>&1
  # Quit the app icon too, but only if it is open (so this never launches it)
  osascript -e 'if application "ProPre2.0" is running then tell application "ProPre2.0" to quit' >/dev/null 2>&1 &
}

echo $$ > "$PIDFILE"
# Shutdown and logout send TERM or HUP to every process: stop everything then
trap 'stop_all; rm -f "$PIDFILE"; exit 0' TERM HUP INT

last=$(date +%s)
while running; do
  sleep 2
  now=$(date +%s)
  if [ $((now - last)) -gt $GAP ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') The Mac woke from sleep. Stopping ProPre2.0."
    stop_all
    break
  fi
  last=$now
done

rm -f "$PIDFILE"
exit 0
