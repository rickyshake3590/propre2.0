#!/usr/bin/env python3
import subprocess
import sys

PORT = 3000
PROFILE_MARKER = "propre-output-profile"
IS_WIN = sys.platform == "win32"


def server_pids():
    if IS_WIN:
        out = subprocess.run(["netstat", "-ano", "-p", "TCP"], capture_output=True, text=True).stdout
        pids = set()
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 5 and parts[1].endswith(f":{PORT}") and parts[3] == "LISTENING":
                pids.add(parts[4])
        return pids
    out = subprocess.run(["lsof", "-ti", f"tcp:{PORT}", "-sTCP:LISTEN"], capture_output=True, text=True).stdout
    return set(out.split())


def close_output_window():
    if IS_WIN:
        script = (f"Get-CimInstance Win32_Process | Where-Object {{ $_.CommandLine -like '*{PROFILE_MARKER}*' }} "
                  "| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }")
        subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True)
    else:
        subprocess.run(["pkill", "-f", PROFILE_MARKER], capture_output=True)


def main():
    pids = server_pids()
    if not pids:
        print("ProPre2.0 is not running.")
    for pid in pids:
        if IS_WIN:
            subprocess.run(["taskkill", "/PID", pid, "/F"], capture_output=True)
        else:
            subprocess.run(["kill", pid], capture_output=True)
    close_output_window()
    if pids:
        print("ProPre2.0 stopped.")


if __name__ == "__main__":
    main()
