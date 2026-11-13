#!/bin/bash
# Stops ProPre2.0 and closes the fullscreen output window.
cd "$(dirname "$0")" || exit 1
PORT="${PROPRE_PORT:-3000}"
WATCH_PIDFILE="$PWD/.propre-watch.pid"

# Stop the sleep/shutdown watcher too. Skip it when the watcher is the one calling this script,
# because it is still in the middle of stopping things.
if [ -f "$WATCH_PIDFILE" ]; then
  wpid="$(cat "$WATCH_PIDFILE" 2>/dev/null)"
  if [ -n "$wpid" ] && [ "$wpid" != "$PPID" ]; then
    kill "$wpid" 2>/dev/null
  fi
  rm -f "$WATCH_PIDFILE"
fi

PIDS=$(lsof -ti tcp:$PORT -sTCP:LISTEN 2>/dev/null)
if [ -z "$PIDS" ]; then
  echo "ProPre2.0 is not running."
else
  kill $PIDS
  echo "ProPre2.0 stopped."
fi
pkill -f propre-output-profile 2>/dev/null
exit 0
