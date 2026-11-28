#!/usr/bin/env bash
# B1: GPS simulator. Registers a test device in Traccar (if missing) and sends positions
# with the OsmAnd protocol, driving a loop around El Poblado (Medellin).
# Admin credentials come from the environment (.env), never from the repo:
#   TRACCAR_ADMIN_EMAIL, TRACCAR_ADMIN_PASSWORD
# Usage: scripts/gps-simulator.sh <env> [points] [interval_seconds]
set -euo pipefail

ENV_NAME="${1:?usage: gps-simulator.sh <env> [points] [interval_seconds]}"
POINTS="${2:-60}"
INTERVAL="${3:-2}"
: "${TRACCAR_ADMIN_EMAIL:?set TRACCAR_ADMIN_EMAIL in .env}"
: "${TRACCAR_ADMIN_PASSWORD:?set TRACCAR_ADMIN_PASSWORD in .env}"

case "$ENV_NAME" in
  prod) WEB_PORT=8082 OSMAND_PORT=5055 ;;
  uat) WEB_PORT=8083 OSMAND_PORT=5056 ;;
  dev) WEB_PORT=8084 OSMAND_PORT=5057 ;;
  *) echo "ENV must be dev, uat or prod" >&2; exit 1 ;;
esac

API="http://localhost:$WEB_PORT/api"
UNIQUE_ID="fz-sim-001"
AUTH=(-u "$TRACCAR_ADMIN_EMAIL:$TRACCAR_ADMIN_PASSWORD")

if [[ "$(curl -s "${AUTH[@]}" "$API/devices?uniqueId=$UNIQUE_ID")" == "[]" ]]; then
  curl -sf "${AUTH[@]}" -H 'Content-Type: application/json' \
    -d "{\"name\":\"Vehiculo simulado\",\"uniqueId\":\"$UNIQUE_ID\"}" "$API/devices" >/dev/null
  echo "Device $UNIQUE_ID created in $ENV_NAME"
fi

echo "Sending $POINTS positions to localhost:$OSMAND_PORT (OsmAnd), one every ${INTERVAL}s"
for i in $(seq 0 $((POINTS - 1))); do
  read -r LAT LON BEARING < <(awk -v i="$i" -v n="$POINTS" 'BEGIN {
    pi = atan2(0, -1); a = 2 * pi * i / n
    printf "%.6f %.6f %.0f\n", 6.2088 + 0.01 * sin(a), -75.5711 + 0.01 * cos(a), (360 - a * 180 / pi) % 360 }')
  SPEED=$(( 20 + RANDOM % 20 )) # knots
  CODE="$(curl -s -o /dev/null -w '%{http_code}' \
    "http://localhost:$OSMAND_PORT/?id=$UNIQUE_ID&lat=$LAT&lon=$LON&timestamp=$(date +%s)&speed=$SPEED&bearing=$BEARING" || true)"
  printf '%3d/%d lat=%s lon=%s speed=%skn -> HTTP %s\n' "$((i + 1))" "$POINTS" "$LAT" "$LON" "$SPEED" "$CODE"
  sleep "$INTERVAL"
done
echo "Done. Open http://localhost:$WEB_PORT to see the device on the map."
