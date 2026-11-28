#!/usr/bin/env bash
# O6: terminal view of an environment: latest value of each metric and state of each alarm.
# (Floci's web console only shows the default account, FL-07.)
# Usage (from the repo root, after `make tf-init ENV=<env>`): scripts/status.sh <env>
set -euo pipefail

ENV_NAME="${1:?usage: status.sh <env>}"
NAMESPACE="AVL/Traccar"
NAME="$(terraform -chdir=infra/environments output -raw cluster_name)"
START="$(date -u -d '-15 min' +%Y-%m-%dT%H:%M:%SZ)"
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "Traccar $ENV_NAME - last 15 minutes (latest datapoint)"
printf '  %-14s %10s %10s\n' METRIC LATEST MAX
for spec in Availability:Minimum LatencyMs:Average Errors:Sum CpuPercent:Average MemoryMiB:Average; do
  metric="${spec%%:*}"
  stat="${spec##*:}"
  read -r latest max < <(aws cloudwatch get-metric-statistics --namespace "$NAMESPACE" --metric-name "$metric" \
    --dimensions "Name=Environment,Value=$ENV_NAME" --statistics "$stat" Maximum --period 60 \
    --start-time "$START" --end-time "$END" --output json |
    jq -r --arg s "$stat" '(.Datapoints | sort_by(.Timestamp)) as $d
      | if ($d | length) == 0 then "- -" else "\($d[-1][$s]) \([$d[].Maximum] | max)" end')
  printf '  %-14s %10s %10s\n' "$metric" "$latest" "$max"
done

echo
echo "Alarms"
aws cloudwatch describe-alarms --alarm-name-prefix "$NAME-" \
  --query 'MetricAlarms[].[AlarmName,StateValue,StateReason]' --output text |
  awk -F'\t' '{ printf "  %-32s %-18s %s\n", $1, $2, $3 }'
