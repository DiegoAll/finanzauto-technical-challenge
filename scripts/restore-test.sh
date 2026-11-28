#!/usr/bin/env bash
# O8: prove that the latest backup of an environment can be restored.
# Downloads the newest dump from S3, verifies its checksum, restores it into a temporary,
# isolated PostgreSQL container and compares row counts with the ones recorded at backup time.
# Usage (from the repo root, after `make tf-init ENV=<env>`): scripts/restore-test.sh <env>
set -euo pipefail

ENV_NAME="${1:?usage: restore-test.sh <env>}"
PG_IMAGE="postgres:16-alpine"
CONTAINER="traccar-restore-test-${ENV_NAME}"

BUCKET="$(terraform -chdir=infra/environments output -raw backup_bucket 2>/dev/null || true)"
if [[ -z "$BUCKET" || "$BUCKET" == "null" ]]; then
  echo "Environment $ENV_NAME has no backup bucket" >&2
  exit 1
fi

LATEST="$(aws s3 ls "s3://$BUCKET/traccar/" | awk '{print $4}' | grep '\.dump$' | sort | tail -1)"
if [[ -z "$LATEST" ]]; then
  echo "No backups found in s3://$BUCKET/traccar/" >&2
  exit 1
fi
NAME="${LATEST%.dump}"
echo "Latest backup: $LATEST"

WORKDIR="$(mktemp -d)"
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; rm -rf "$WORKDIR"; }
trap cleanup EXIT

for f in "$NAME.dump" "$NAME.dump.sha256" "$NAME.counts"; do
  aws s3 cp --only-show-errors "s3://$BUCKET/traccar/$f" "$WORKDIR/$f"
done

echo "Verifying checksum"
(cd "$WORKDIR" && sha256sum --check --strict "$NAME.dump.sha256")

echo "Starting temporary PostgreSQL ($CONTAINER), isolated from $ENV_NAME"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER" \
  -e POSTGRES_USER=traccar -e POSTGRES_DB=traccar \
  -e POSTGRES_PASSWORD="$(openssl rand -hex 16)" \
  "$PG_IMAGE" >/dev/null
for _ in $(seq 1 30); do
  docker exec "$CONTAINER" pg_isready -U traccar -d traccar >/dev/null 2>&1 && break
  sleep 2
done

echo "Restoring $LATEST"
docker exec -i "$CONTAINER" pg_restore -U traccar -d traccar --no-owner --exit-on-error < "$WORKDIR/$NAME.dump"

psql_dst() { docker exec "$CONTAINER" psql -U traccar -d traccar -At -c "$1"; }
{
  echo "tables=$(psql_dst "select count(*) from information_schema.tables where table_schema='public' and table_name like 'tc_%'")"
  for t in tc_users tc_devices tc_positions; do
    echo "$t=$(psql_dst "select count(*) from $t")"
  done
} > "$WORKDIR/restored.counts"

echo "Row counts (backup time vs restored):"
paste -d' ' "$WORKDIR/$NAME.counts" "$WORKDIR/restored.counts" | awk '{split($1,a,"=");split($2,b,"="); printf "  %-14s %8s %8s %s\n", a[1], a[2], b[2], (a[2]==b[2]?"OK":"MISMATCH")}'

if ! diff -q "$WORKDIR/$NAME.counts" "$WORKDIR/restored.counts" >/dev/null; then
  echo "Restore test FAILED: counts differ" >&2
  exit 1
fi
echo "Restore test passed: $LATEST restored into a separate database with identical counts"
