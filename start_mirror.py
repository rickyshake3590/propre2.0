#!/usr/bin/env python3
"""Opens the ProPre2.0 output fullscreen on a SECOND computer (E2).
It shows exactly what the main computer (E1) is showing: same timer, same time, same position.

Nothing runs on this computer except the browser window. Start ProPre2.0 on E1 first.
To close the window, run stop_propre.py on this computer.
"""
import sys
import time
import urllib.request

from start_propre import open_output_fullscreen, pause

# The address of the main computer (E1). It is shown at the top of the E1 dashboard.
# On a Mac this is usually the computer's name with .local on the end, e.g. "E1.local",
# or a number like "169.254.10.5" if that name doesn't work.
E1_ADDRESS = "E1.local"
PORT = 3000


def reachable(base):
    try:
        urllib.request.urlopen(f"{base}/api/live", timeout=3)
        return True
    except Exception:
        return False


def main():
    address = sys.argv[1] if len(sys.argv) > 1 else E1_ADDRESS
    base = f"http://{address}:{PORT}"
    print(f"Looking for ProPre2.0 on {address} ...")
    for _ in range(10):
        if reachable(base):
            break
        time.sleep(2)
    else:
        pause(f"Could not reach {address}.\n"
              "Check that ProPre2.0 is running on E1, the ethernet cable is connected,\n"
              "and the E1_ADDRESS in start_mirror.py matches the address shown on the E1 dashboard.")
        return

    browser = open_output_fullscreen(f"{base}/output.html")
    if browser:
        print(f"Mirrored output opened fullscreen in {browser}.")
    else:
        print(f"Open {base}/output.html and press F11 (or Ctrl+Cmd+F on Mac).")


if __name__ == "__main__":
    main()
