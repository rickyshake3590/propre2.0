#!/usr/bin/env python3
import os
import subprocess
import sys
import time
import urllib.request
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PORT = 3000
BASE = f"http://localhost:{PORT}"
PROFILE_DIR = Path.home() / "propre-output-profile"
IS_MAC = sys.platform == "darwin"
IS_WIN = sys.platform == "win32"


def pause(message):
    print(message)
    input("Press Enter to close...")


def server_running():
    try:
        urllib.request.urlopen(f"{BASE}/api/timers", timeout=1)
        return True
    except Exception:
        return False


def start_server():
    log = open(ROOT / "server.log", "a")
    extra = {}
    if IS_WIN:
        extra["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
    else:
        extra["start_new_session"] = True
    subprocess.Popen([sys.executable, "server.py"], cwd=ROOT, stdin=subprocess.DEVNULL,
                     stdout=log, stderr=log, **extra)
    for _ in range(50):
        if server_running():
            return True
        time.sleep(0.2)
    return False


def browser_candidates():
    if IS_MAC:
        return [
            (["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"], "chromium"),
            (["/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"], "chromium"),
            (["/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"], "chromium"),
            (["/Applications/Firefox.app/Contents/MacOS/firefox"], "firefox"),
        ]
    if IS_WIN:
        pf = os.environ.get("ProgramFiles", r"C:\Program Files")
        pf86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
        local = os.environ.get("LOCALAPPDATA", "")
        return [
            ([rf"{pf}\Google\Chrome\Application\chrome.exe",
              rf"{pf86}\Google\Chrome\Application\chrome.exe",
              rf"{local}\Google\Chrome\Application\chrome.exe"], "chromium"),
            ([rf"{pf86}\Microsoft\Edge\Application\msedge.exe",
              rf"{pf}\Microsoft\Edge\Application\msedge.exe"], "chromium"),
            ([rf"{pf}\Mozilla Firefox\firefox.exe",
              rf"{pf86}\Mozilla Firefox\firefox.exe"], "firefox"),
        ]
    return []


def open_output_fullscreen():
    url = f"{BASE}/output.html"
    for paths, kind in browser_candidates():
        exe = next((p for p in paths if os.path.exists(p)), None)
        if not exe:
            continue
        if kind == "chromium":
            subprocess.Popen([exe, "--kiosk", f"--user-data-dir={PROFILE_DIR}", "--no-first-run", url])
        else:
            subprocess.Popen([exe, "-kiosk", url])
        return exe

    if IS_MAC and os.path.exists("/Applications/Safari.app"):
        subprocess.Popen(["open", "-a", "Safari", url])
        time.sleep(2)
        subprocess.run(["osascript", "-e",
                        'tell application "System Events" to keystroke "f" using {command down, control down}'],
                       capture_output=True)
        return "Safari"

    webbrowser.open(url)
    return None


def main():
    if server_running():
        print("ProPre2.0 is already running.")
    else:
        if not start_server():
            pause(f"The server did not start. See {ROOT / 'server.log'} for details.")
            return
        print("ProPre2.0 started.")

    webbrowser.open(f"{BASE}/index.html")
    browser = open_output_fullscreen()
    if browser:
        print(f"Output opened fullscreen in {browser}.")
    else:
        print("No kiosk-capable browser found. Open output.html and press F11 (or Ctrl+Cmd+F on Mac).")


if __name__ == "__main__":
    main()
