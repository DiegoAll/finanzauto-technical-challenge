# Traccar GPS server image.
# Built once per commit in CI and promoted unchanged to Dev, UAT and Prod.
# Configuration comes only from environment variables: no traccar.xml with credentials.
FROM traccar/traccar:6.17.0-alpine@sha256:b32d9346adf46df7c33c58577e17ad60f6feadd1f3cd87c876041f6c79317ef1

# Apply Alpine security patches released after the upstream image was built,
# then create an unprivileged user. Traccar only writes to data/, logs/, override/ and media/.
# hadolint ignore=DL3017
RUN apk upgrade --no-cache \
 && addgroup -S -g 10001 traccar \
 && adduser -S -D -H -u 10001 -G traccar traccar \
 && mkdir -p /opt/traccar/override /opt/traccar/media \
 && chown -R traccar:traccar /opt/traccar/data /opt/traccar/logs /opt/traccar/override /opt/traccar/media

USER 10001:10001

# Ports: 8082 web UI/API, 5055 OsmAnd protocol (GPS simulator).
EXPOSE 8082 5055

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8082/api/server"]
