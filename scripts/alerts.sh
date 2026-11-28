#!/usr/bin/env bash
# O6: read the alerts delivered by SNS to the environment's SQS inbox.
# Usage (from the repo root, after `make tf-init ENV=<env>`): scripts/alerts.sh <env>
set -euo pipefail

ENV_NAME="${1:?usage: alerts.sh <env>}"
NAME="$(terraform -chdir=infra/environments output -raw cluster_name)"
QUEUE_URL="$(aws sqs get-queue-url --queue-name "$NAME-alerts" --query QueueUrl --output text)"

echo "Alerts received for $ENV_NAME ($NAME-alerts)"
aws sqs receive-message --queue-url "$QUEUE_URL" --max-number-of-messages 10 --wait-time-seconds 2 --output json |
  jq -r '.Messages // [] | .[] | .Body | fromjson | .Message | fromjson
    | "  \(.StateChangeTime)  \(.AlarmName)  \(.OldStateValue) -> \(.NewStateValue)  (\(.NewStateReason))"'
