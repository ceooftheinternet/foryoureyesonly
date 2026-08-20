#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/.polygon-002"
CFG="$HOME/.config/polygon-002"
UNITS="$HOME/.config/systemd/user"
STATE="$HOME/.local/state/polygon-002"

mkdir -p "$STATE"

cp "$CFG/api.env" "$ROOT/recovery/api.env"
cp "$CFG/gateway.env" "$ROOT/recovery/gateway.env"

printf '%s\n' \
    "$(date --iso-8601=seconds)" \
    > "$STATE/incident-start"

SCENARIO=$(( $(od -An -N2 -tu2 /dev/urandom) % 3 ))

case "$SCENARIO" in

    0)
        # gateway -> wrong upstream
        sed -i \
            's#http://127.0.0.1:18180#http://127.0.0.1:18181#' \
            "$CFG/gateway.env"

        systemctl --user restart polygon-gateway.service
        ;;

    1)
        # API -> required dependency disappears
        sed -i \
            "s#POLYGON_GREETING_FILE=.*#POLYGON_GREETING_FILE=$ROOT/app/missing-greeting.txt#" \
            "$CFG/api.env"

        systemctl --user restart polygon-api.service
        ;;

    2)
        # gateway cannot read its own environment file
        chmod 000 "$CFG/gateway.env"

        systemctl --user restart polygon-gateway.service
        ;;

esac

rm -f "$HOME/polygon002-arm.sh"

echo
echo "============================================"
echo "        POLYGON INCIDENT #002 ARMED"
echo "============================================"
echo
echo "SIMULATED PRODUCTION INCIDENT"
echo
echo "User report:"
echo "  The Polygon dashboard is unavailable."
echo
echo "Contract:"
echo "  http://127.0.0.1:18080/dashboard"
echo "  must return HTTP 200."
echo
echo "Known:"
echo "  Host is reachable."
echo "  SSH is unrelated to this exercise."
echo
echo "Unknown:"
echo "  affected component"
echo "  failure mode"
echo "  root cause"
echo
echo "Restrictions:"
echo "  - no reboot"
echo "  - no sudo"
echo "  - do not inspect ~/.polygon-002/recovery/"
echo "  - do not inspect deleted launcher"
echo "  - do not blindly restart everything"
echo
echo "OBJECTIVE:"
echo "  Restore the dashboard."
echo "  Establish the root cause."
echo "  Prove recovery."
echo
echo "============================================"
