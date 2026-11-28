#!/usr/bin/env bash
# O6: one observation of an environment, published as CloudWatch custom metrics.
#   Availability (0/1) and LatencyMs  -> GET /api/server
#   Errors                            -> ERROR lines in CloudWatch Logs during the last minute
#   CpuPercent and MemoryMiB          -> docker stats of the Traccar task container
# Floci does not evaluate alarms (FL-09), so the probe also sets the alarm states.
# On AWS this second part is removed: CloudWatch evaluates the alarms by itself.
# Usage (from the repo root, after `make tf-init ENV=<env>`): scripts/probe.sh <env>
set -euo pipefail

ENV_NAME="${1:?usage: probe.sh <env>}"
NAMESPACE="AVL/Traccar"

tf_out() { terraform -chdir=infra/environments output -raw "$1"; }
URL="$(tf_out web_url)"
LOG_GROUP="$(tf_out log_group_name)"
NAME="$(tf_out cluster_name)" # avl-traccar-<env>, prefix of the alarm names
PORT="${URL##*:}"

# Availability and latency
read -r CODE SECONDS_TOTAL < <(curl -s -o /dev/null -w '%{http_code} %{time_total}\n' --max-time 5 "$URL/api/server" || echo "000 5")
AVAILABLE=0
[[ "$CODE" == "200" ]] && AVAILABLE=1
LATENCY_MS="$(awk -v s="$SECONDS_TOTAL" 'BEGIN { printf "%d", s * 1000 }')"

# Errors logged by Traccar in the last minute
SINCE_MS=$(( ($(date +%s) - 60) * 1000 ))
ERRORS="$(aws logs filter-log-events --log-group-name "$LOG_GROUP" --start-time "$SINCE_MS" \
  --filter-pattern ERROR --query 'length(events)' --output text 2>/dev/null || echo 0)"
[[ "$ERRORS" =~ ^[0-9]+$ ]] || ERRORS=0

# CPU and memory of the task container (Floci publishes the web port on the host)
CPU=""
MEM=""
CONTAINER="$(docker ps -q --filter name=floci-aws-ecs --filter "publish=$PORT" | head -1)"
if [[ -n "$CONTAINER" ]]; then
  read -r CPU_RAW MEM_RAW < <(docker stats --no-stream --format '{{.CPUPerc}} {{.MemUsage}}' "$CONTAINER" | awk '{print $1, $2}')
  CPU="${CPU_RAW%\%}"
  MEM="$(awk -v m="$MEM_RAW" 'BEGIN {
    v = m + 0
    if (m ~ /GiB$/) v = v * 1024; else if (m ~ /KiB$/) v = v / 1024; else if (m ~ /B$/ && m !~ /iB$/) v = v / 1048576
    printf "%.1f", v }')"
fi

DIM="Name=Environment,Value=$ENV_NAME"
DATA="MetricName=Availability,Value=$AVAILABLE,Dimensions=[{$DIM}] MetricName=LatencyMs,Value=$LATENCY_MS,Unit=Milliseconds,Dimensions=[{$DIM}] MetricName=Errors,Value=$ERRORS,Unit=Count,Dimensions=[{$DIM}]"
[[ -n "$CPU" ]] && DATA="$DATA MetricName=CpuPercent,Value=$CPU,Unit=Percent,Dimensions=[{$DIM}]"
[[ -n "$MEM" ]] && DATA="$DATA MetricName=MemoryMiB,Value=$MEM,Unit=Megabytes,Dimensions=[{$DIM}]"
# shellcheck disable=SC2086 # one argument per metric
aws cloudwatch put-metric-data --namespace "$NAMESPACE" --metric-data $DATA

# Alarm evaluation (FL-09). Only state changes trigger the SNS action, so no alert spam.
set_alarm() {
  local alarm="$1" breaching="$2" reason="$3" want current
  want="OK"
  [[ "$breaching" == "1" ]] && want="ALARM"
  current="$(aws cloudwatch describe-alarms --alarm-names "$alarm" --query 'MetricAlarms[0].StateValue' --output text)"
  if [[ "$current" != "$want" ]]; then
    aws cloudwatch set-alarm-state --alarm-name "$alarm" --state-value "$want" --state-reason "$reason"
    echo "  alarm $alarm: $current -> $want"
  fi
}
set_alarm "$NAME-availability" "$(( 1 - AVAILABLE ))" "probe: /api/server returned HTTP $CODE"
set_alarm "$NAME-errors" "$(( ERRORS >= 5 ? 1 : 0 ))" "probe: $ERRORS ERROR lines in the last minute"
if [[ -n "$CPU" ]]; then
  set_alarm "$NAME-cpu" "$(awk -v c="$CPU" 'BEGIN { print (c > 80) ? 1 : 0 }')" "probe: CPU at ${CPU}%"
fi

echo "$(date -u +%H:%M:%S) $ENV_NAME available=$AVAILABLE http=$CODE latency=${LATENCY_MS}ms errors=$ERRORS cpu=${CPU:-n/a}% mem=${MEM:-n/a}MiB"
