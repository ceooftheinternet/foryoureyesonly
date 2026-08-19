#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/.polygon"
APP="$ROOT/app"
UNIT="$HOME/.config/systemd/user/polygon-web.service"
REC="$ROOT/recovery"

mkdir -p "$APP" "$REC" "$(dirname "$UNIT")"

# ---------- BASE SERVICE ----------

cat > "$APP/server.py" <<'PY'
#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"POLYGON WEB SERVICE: OK\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(fmt % args)

HTTPServer(("127.0.0.1", 18080), Handler).serve_forever()
PY

chmod +x "$APP/server.py"

cat > "$UNIT" <<EOF
[Unit]
Description=Polygon Web Service

[Service]
ExecStart=/usr/bin/python3 $APP/server.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now polygon-web.service

sleep 1

# ---------- VERIFY BASELINE ----------

if ! curl -fsS http://127.0.0.1:18080/ >/dev/null; then
    echo "ERROR: baseline service did not start."
    exit 1
fi

# ---------- RECOVERY ----------

cp "$APP/server.py" "$REC/server.py"
cp "$UNIT" "$REC/polygon-web.service"

# ---------- RANDOM INCIDENT ----------

INCIDENT=$(( $(od -An -N2 -tu2 /dev/urandom) % 3 ))

case "$INCIDENT" in

    0)
        # Configuration failure
        sed -i 's/127.0.0.1/127.0.0.2/' "$APP/server.py"
        ;;

    1)
        # Permission failure
        chmod 000 "$APP/server.py"
        ;;

    2)
        # Broken executable path
        sed -i 's#server.py#server-broken.py#' "$UNIT"
        ;;

esac

systemctl --user daemon-reload
systemctl --user restart polygon-web.service

# ---------- DO NOT LEAVE THE ANSWER LYING AROUND ----------

rm -f "$HOME/polygon-launcher.sh"

echo
echo "======================================"
echo "       POLYGON INCIDENT ARMED"
echo "======================================"
echo
echo "INCIDENT #001"
echo
echo "A local service has developed a fault."
echo
echo "SSH access:        OK"
echo "Host:              OK"
echo "Target:            UNKNOWN"
echo
echo "Your objective:"
echo "  1. Discover the affected service."
echo "  2. Determine why it is failing."
echo "  3. Restore normal operation."
echo "  4. Prove that it works."
echo
echo "Do NOT inspect ~/.polygon/recovery."
echo "Do NOT recreate the service from scratch."
echo "Do NOT reboot the machine."
echo
echo "======================================"
