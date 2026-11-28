#!/usr/bin/env bash
# O8: dump the Traccar database of an environment to its S3 backup bucket.
# Usage (from the repo root, after `make tf-init ENV=<env>`): scripts/backup.sh <env>
# The password is read from Secrets Manager and passed to the container through the
# environment (never on the command line or on disk).
set -euo pipefail

ENV_NAME="${1:?usage: backup.sh <env>}"
PG_IMAGE="postgres:16-alpine"
NETWORK="avl" # Floci's RDS proxy is only reachable from this Docker network

tf_out() { terraform -chdir=infra/environments output -raw "$1"; }

DB_HOST="$(tf_out db_address)"
DB_PORT="$(tf_out db_port)"
SECRET_ARN="$(tf_out db_secret_arn)"
BUCKET="$(tf_out backup_bucket 2>/dev/null || true)"
if [[ -z "$BUCKET" || "$BUCKET" == "null" ]]; then
  echo "Environment $ENV_NAME has no backup bucket (enable_backups = false)" >&2
  exit 1
fi

PGPASSWORD="$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)"
export PGPASSWORD

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
NAME="traccar-${ENV_NAME}-${STAMP}"

psql_src() {
  docker run --rm --network "$NETWORK" -e PGPASSWORD "$PG_IMAGE" \
    psql -h "$DB_HOST" -p "$DB_PORT" -U traccar -d traccar -At -c "$1"
}

echo "Recording row counts of $ENV_NAME"
{
  echo "tables=$(psql_src "select count(*) from information_schema.tables where table_schema='public' and table_name like 'tc_%'")"
  for t in tc_users tc_devices tc_positions; do
    echo "$t=$(psql_src "select count(*) from $t")"
  done
} > "$WORKDIR/$NAME.counts"
cat "$WORKDIR/$NAME.counts"

echo "Dumping $ENV_NAME database ($DB_HOST:$DB_PORT)"
docker run --rm --network "$NETWORK" -e PGPASSWORD "$PG_IMAGE" \
  pg_dump -h "$DB_HOST" -p "$DB_PORT" -U traccar -d traccar -Fc > "$WORKDIR/$NAME.dump"

(cd "$WORKDIR" && sha256sum "$NAME.dump" > "$NAME.dump.sha256")

for f in "$NAME.dump" "$NAME.dump.sha256" "$NAME.counts"; do
  aws s3 cp --only-show-errors "$WORKDIR/$f" "s3://$BUCKET/traccar/$f"
done

echo "Backup stored: s3://$BUCKET/traccar/$NAME.dump ($(du -h "$WORKDIR/$NAME.dump" | cut -f1))"
