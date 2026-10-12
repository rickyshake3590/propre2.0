#!/usr/bin/env python3
import json
import os
import re
import socketserver
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent
DB_PATH = os.environ.get("PROPRE_DB", str(ROOT / "timers.db"))
PORT = 3000

TYPES = ["countdown", "countup", "altar-call"]
POSITIONS = ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right",
             "bottom-left", "bottom-center", "bottom-right"]
SIZES = ["small", "medium", "large"]
COLOURS = ["white", "yellow", "red"]

STATIC_TYPES = {".html": "text/html; charset=utf-8", ".js": "application/javascript; charset=utf-8", ".ttf": "font/ttf"}

TABLE_COLUMNS = """
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'countdown',
  position TEXT NOT NULL,
  size TEXT NOT NULL DEFAULT 'large',
  colour TEXT NOT NULL DEFAULT 'white',
  show_title INTEGER NOT NULL DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  show_current_time INTEGER NOT NULL DEFAULT 0
"""

live = {"timer": None, "elapsed": 0.0, "isRunning": False, "stamp": time.time()}
live_lock = threading.Lock()


def connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = connect()
    conn.execute(f"CREATE TABLE IF NOT EXISTS timers ({TABLE_COLUMNS})")
    try:
        conn.execute("ALTER TABLE timers ADD COLUMN show_current_time INTEGER NOT NULL DEFAULT 0")
    except sqlite3.OperationalError:
        pass
    row = conn.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='timers'").fetchone()
    if row and re.search(r"name TEXT NOT NULL UNIQUE", row["sql"], re.I):
        conn.executescript(f"""
            BEGIN;
            CREATE TABLE timers_new ({TABLE_COLUMNS});
            INSERT INTO timers_new (id, name, duration_seconds, type, position, size, colour, show_title,
                                    created_at, updated_at, show_current_time)
              SELECT id, name, duration_seconds, type, position, size, colour, show_title,
                     created_at, updated_at, show_current_time FROM timers;
            DROP TABLE timers;
            ALTER TABLE timers_new RENAME TO timers;
            COMMIT;
        """)
    conn.commit()
    conn.close()


def parse_int(value):
    if isinstance(value, bool):
        return None
    try:
        return int(float(value))
    except (TypeError, ValueError, OverflowError):
        return None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send_json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_json(self):
        length = int(self.headers.get("Content-Length") or 0)
        try:
            data = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            return None
        return data if isinstance(data, dict) else None

    def serve_static(self, path):
        rel = "index.html" if path == "/" else unquote(path).lstrip("/")
        try:
            target = (ROOT / rel).resolve()
        except (ValueError, OSError):
            return self.send_json(404, {"error": "Not found"})
        content_type = STATIC_TYPES.get(target.suffix.lower())
        if content_type is None or ROOT not in target.parents or not target.is_file():
            return self.send_json(404, {"error": "Not found"})
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/timers":
            conn = connect()
            rows = conn.execute("SELECT * FROM timers ORDER BY created_at ASC").fetchall()
            conn.close()
            return self.send_json(200, [dict(r) for r in rows])
        if path == "/api/live":
            with live_lock:
                elapsed = live["elapsed"] + ((time.time() - live["stamp"]) if live["isRunning"] else 0)
                return self.send_json(200, {"timer": live["timer"], "elapsed": elapsed,
                                            "isRunning": live["isRunning"]})
        self.serve_static(path)

    def do_POST(self):
        path = urlparse(self.path).path
        body = self.read_json()
        if body is None:
            return self.send_json(400, {"error": "Invalid JSON"})

        if path == "/api/live":
            with live_lock:
                live.update(timer=body.get("timer") or None,
                            elapsed=float(body.get("elapsed") or 0),
                            isRunning=bool(body.get("isRunning")),
                            stamp=time.time())
            return self.send_json(200, {"success": True})

        if path != "/api/timers":
            return self.send_json(404, {"error": "Not found"})

        name = body.get("name")
        if not isinstance(name, str) or not name.strip():
            return self.send_json(400, {"error": "Timer name is required"})
        timer_type = body.get("type") or "countdown"
        if timer_type not in TYPES:
            return self.send_json(400, {"error": f"Type must be one of: {', '.join(TYPES)}"})
        duration = parse_int(body.get("duration_seconds"))
        minimum = 0 if timer_type == "countup" else 1
        if duration is None or duration < minimum:
            return self.send_json(400, {"error": f"Duration must be at least {minimum} second(s)"})
        position = body.get("position")
        if position not in POSITIONS:
            return self.send_json(400, {"error": f"Position must be one of: {', '.join(POSITIONS)}"})
        size = body.get("size") or "large"
        if size not in SIZES:
            return self.send_json(400, {"error": f"Size must be one of: {', '.join(SIZES)}"})
        colour = body.get("colour") or "white"
        if colour not in COLOURS:
            return self.send_json(400, {"error": f"Colour must be one of: {', '.join(COLOURS)}"})
        show_title = 1 if body.get("show_title", True) else 0
        show_current_time = 1 if body.get("show_current_time") else 0

        conn = connect()
        cur = conn.execute(
            "INSERT INTO timers (name, duration_seconds, type, position, size, colour, show_title, show_current_time) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (name.strip(), duration, timer_type, position, size, colour, show_title, show_current_time))
        conn.commit()
        row = conn.execute("SELECT * FROM timers WHERE id = ?", (cur.lastrowid,)).fetchone()
        conn.close()
        self.send_json(201, dict(row))

    def do_PUT(self):
        path = urlparse(self.path).path
        if not path.startswith("/api/timers/"):
            return self.send_json(404, {"error": "Not found"})
        timer_id = parse_int(path.rsplit("/", 1)[1])
        body = self.read_json()
        if body is None:
            return self.send_json(400, {"error": "Invalid JSON"})

        updates, params = [], []
        if "duration_seconds" in body:
            duration = parse_int(body["duration_seconds"])
            if duration is None or duration < 1:
                return self.send_json(400, {"error": "Duration must be at least 1 second"})
            updates.append("duration_seconds = ?")
            params.append(duration)
        if "show_title" in body:
            updates.append("show_title = ?")
            params.append(1 if body["show_title"] else 0)
        if not updates:
            return self.send_json(400, {"error": "No fields to update"})
        updates.append("updated_at = CURRENT_TIMESTAMP")

        conn = connect()
        cur = conn.execute(f"UPDATE timers SET {', '.join(updates)} WHERE id = ?", params + [timer_id])
        conn.commit()
        if cur.rowcount == 0:
            conn.close()
            return self.send_json(404, {"error": "Timer not found"})
        row = conn.execute("SELECT * FROM timers WHERE id = ?", (timer_id,)).fetchone()
        conn.close()
        self.send_json(200, dict(row))

    def do_DELETE(self):
        path = urlparse(self.path).path
        if not path.startswith("/api/timers/"):
            return self.send_json(404, {"error": "Not found"})
        timer_id = parse_int(path.rsplit("/", 1)[1])
        conn = connect()
        cur = conn.execute("DELETE FROM timers WHERE id = ?", (timer_id,))
        conn.commit()
        conn.close()
        if cur.rowcount == 0:
            return self.send_json(404, {"error": "Timer not found"})
        self.send_json(200, {"success": True, "id": timer_id})


class Server(ThreadingHTTPServer):
    def server_bind(self):
        # HTTPServer.server_bind does a reverse-DNS lookup that can stall for many seconds
        socketserver.TCPServer.server_bind(self)
        self.server_name = "localhost"
        self.server_port = PORT


def main():
    init_db()
    server = Server(("127.0.0.1", PORT), Handler)
    print(f"ProPre2.0 Timer Server running on http://localhost:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
