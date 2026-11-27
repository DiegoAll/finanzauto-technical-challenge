# Traccar GPS server image.
# Built once per commit in CI and promoted unchanged to Dev, UAT and Prod.
# Configuration comes only from environment variables: no traccar.xml with credentials.
FROM traccar/traccar:6.17.0-alpine

# Ports: 8082 web UI/API, 5055 OsmAnd protocol (GPS simulator).
EXPOSE 8082 5055

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8082/api/server || exit 1
