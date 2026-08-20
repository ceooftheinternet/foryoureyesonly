#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/.polygon-002"
CFG="$HOME/.config/polygon-002"
UNITS="$HOME/.config/systemd/user"
STATE="$HOME/.local/state/polygon-002"

mkdir -p \
    "$ROOT/app" \
    "$ROOT/bin" \
    "$ROOT/recovery" \
    "$CFG" \
    "$UNITS" \
    "$STATE"

# ============================================================
# API
# ============================================================

cat > "$ROOT/app/api.py" <<'PY'
#!/usr/bin/env python3

import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

BIND = os.environ.get("POLYGON_BIND", "127.0.0.1")
PORT = int(os.environ.get("POLYGON_PORT", "18180"))
GREETING_FILE = os.environ.get("POLYGON_GREETING_FILE")

if not GREETING_FILE:
    print("POLYGON_GREETING_FILE is not configured", file=sys.stderr)
    sys.exit(2)

try:
    with open(GREETING_FILE, "r", encoding="utf-8") as f:
        greeting = f.read().strip()
except Exception as exc:
    print(f"Failed to load greeting file: {exc}", file=sys.stderr)
    sys.exit(3)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/api/health":
            self.send_response(404)
            self.end_headers()
            return

        body = json.dumps({
            "status": "ok",
            "service": "polygon-api",
            "message": greeting
        }).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"api: {fmt % args}", flush=True)


HTTPServer((BIND, PORT), Handler).serve_forever()
PY

chmod +x "$ROOT/app/api.py"

cat > "$ROOT/app/greeting.txt" <<'EOF'
POLYGON API HEALTHY
EOF

# ============================================================
# GATEWAY
# ============================================================

cat > "$ROOT/app/gateway.py" <<'PY'
#!/usr/bin/env python3

import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

BIND = os.environ.get("POLYGON_BIND", "127.0.0.1")
PORT = int(os.environ.get("POLYGON_PORT", "18080"))
UPSTREAM = os.environ["POLYGON_UPSTREAM"]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/dashboard":
            self.send_response(404)
            self.end_headers()
            return

        try:
            with urllib.request.urlopen(
                UPSTREAM + "/api/health",
                timeout=2
            ) as response:
                payload = json.loads(response.read().decode())

            body = json.dumps({
                "status": "ok",
                "gateway": "healthy",
                "api": payload
            }).encode()

            self.send_response(200)

        except Exception as exc:
            print(f"gateway: upstream failure: {exc}", flush=True)

            body = json.dumps({
                "status": "error",
                "gateway": "healthy",
                "upstream": "unavailable"
            }).encode()

            self.send_response(502)

        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"gateway: {fmt % args}", flush=True)


HTTPServer((BIND, PORT), Handler).serve_forever()
PY

chmod +x "$ROOT/app/gateway.py"

# ============================================================
# WATCH
# ============================================================

cat > "$ROOT/app/watch.py" <<'PY'
#!/usr/bin/env python3

import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

URL = "http://127.0.0.1:18080/dashboard"
LOG = "/home/REPLACE_USER/.local/state/polygon-002/watch.log"

last_state = None


def log(message):
    timestamp = datetime.now(timezone.utc).astimezone().isoformat()
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} {message}\n")


while True:
    try:
        with urllib.request.urlopen(URL, timeout=2) as response:
            code = response.status
            healthy = code == 200
    except Exception as exc:
        healthy = False
        error = str(exc)

    if healthy != last_state:
        if healthy:
            log("dashboard recovered: HTTP 200")
        else:
            log(f"dashboard unhealthy: {error}")
        last_state = healthy

    time.sleep(2)
PY

sed -i "s#REPLACE_USER#$USER#g" "$ROOT/app/watch.py"
chmod +x "$ROOT/app/watch.py"

# ============================================================
# BASELINE CONFIG
# ============================================================

cat > "$CFG/api.env" <<EOF
POLYGON_BIND=127.0.0.1
POLYGON_PORT=18180
POLYGON_GREETING_FILE=$ROOT/app/greeting.txt
EOF

cat > "$CFG/gateway.env" <<EOF
POLYGON_BIND=127.0.0.1
POLYGON_PORT=18080
POLYGON_UPSTREAM=http://127.0.0.1:18180
EOF

chmod 600 "$CFG/api.env" "$CFG/gateway.env"

# ============================================================
# SYSTEMD USER UNITS
# ============================================================

cat > "$UNITS/polygon-api.service" <<EOF
[Unit]
Description=Polygon API

[Service]
EnvironmentFile=$CFG/api.env
ExecStart=/usr/bin/python3 $ROOT/app/api.py
Restart=on-failure
RestartSec=1

[Install]
WantedBy=default.target
EOF

cat > "$UNITS/polygon-gateway.service" <<EOF
[Unit]
Description=Polygon Gateway
After=polygon-api.service
Wants=polygon-api.service

[Service]
EnvironmentFile=$CFG/gateway.env
ExecStart=/usr/bin/python3 $ROOT/app/gateway.py
Restart=on-failure
RestartSec=1

[Install]
WantedBy=default.target
EOF

cat > "$UNITS/polygon-watch.service" <<EOF
[Unit]
Description=Polygon Synthetic Watch
After=polygon-gateway.service
Wants=polygon-gateway.service

[Service]
ExecStart=/usr/bin/python3 $ROOT/app/watch.py
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload

systemctl --user enable --now polygon-api.service
systemctl --user enable --now polygon-gateway.service
systemctl --user enable --now polygon-watch.service

sleep 2

# ============================================================
# BASELINE VERIFICATION
# ============================================================

curl -fsS http://127.0.0.1:18180/api/health >/dev/null
curl -fsS http://127.0.0.1:18080/dashboard >/dev/null

printf '%s\n' \
    "BASELINE HEALTHY" \
    "API:     127.0.0.1:18180" \
    "GATEWAY: 127.0.0.1:18080" \
    "WATCH:   active" \
    "ROOT:    $ROOT"

# ============================================================
# RECOVERY BASELINE
# ============================================================

cp "$CFG/api.env" "$ROOT/recovery/api.env"
cp "$CFG/gateway.env" "$ROOT/recovery/gateway.env"

echo "Installation complete."
