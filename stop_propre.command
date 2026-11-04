#!/bin/bash
# Stops ProPre2.0 and closes the fullscreen output window.
PORT=3000

PIDS=$(lsof -ti tcp:$PORT -sTCP:LISTEN 2>/dev/null)
if [ -z "$PIDS" ]; then
  echo "ProPre2.0 is not running."
else
  kill $PIDS
  echo "ProPre2.0 stopped."
fi
pkill -f propre-output-profile 2>/dev/null
exit 0
