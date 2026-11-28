# --- Observability -------------------------------------------------------------
# Metrics come from scripts/probe.sh (namespace AVL/Traccar, dimension Environment):
# Availability (0/1), LatencyMs, Errors (ERROR lines in the last minute), CpuPercent, MemoryMiB.
# Floci stores metrics and runs alarm actions but does not evaluate alarms (FL-09): the probe
# sets the alarm state. On AWS, CloudWatch evaluates these same alarms by itself.

locals {
  metrics_namespace = "AVL/Traccar"
  metric_dimensions = { Environment = var.environment }
  dashboard_widgets = [
    { title = "Availability (0/1)", metric = "Availability", stat = "Minimum" },
    { title = "Latency (ms)", metric = "LatencyMs", stat = "Average" },
    { title = "Errors per minute", metric = "Errors", stat = "Sum" },
    { title = "CPU (%)", metric = "CpuPercent", stat = "Average" },
    { title = "Memory (MiB)", metric = "MemoryMiB", stat = "Average" },
  ]
}

# Alert channel: SNS topic with an SQS queue as the inbox (email/Slack would be added on AWS).
resource "aws_sns_topic" "alerts" {
  name = "${local.name}-alerts"
}

resource "aws_sqs_queue" "alerts" {
  name                      = "${local.name}-alerts"
  message_retention_seconds = 345600 # 4 days
  sqs_managed_sse_enabled   = true
}

data "aws_iam_policy_document" "alerts_queue" {
  statement {
    sid       = "AllowAlertsTopic"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.alerts.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "alerts" {
  queue_url = aws_sqs_queue.alerts.id
  policy    = data.aws_iam_policy_document.alerts_queue.json
}

resource "aws_sns_topic_subscription" "alerts_queue" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.alerts.arn
}

resource "aws_cloudwatch_metric_alarm" "availability" {
  alarm_name          = "${local.name}-availability"
  alarm_description   = "Traccar /api/server is not answering."
  namespace           = local.metrics_namespace
  metric_name         = "Availability"
  dimensions          = local.metric_dimensions
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.name}-errors"
  alarm_description   = "Traccar logged 5 or more ERROR lines in one minute."
  namespace           = local.metrics_namespace
  metric_name         = "Errors"
  dimensions          = local.metric_dimensions
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${local.name}-cpu"
  alarm_description   = "Traccar container CPU above 80%."
  namespace           = local.metrics_namespace
  metric_name         = "CpuPercent"
  dimensions          = local.metric_dimensions
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = local.name
  dashboard_body = jsonencode({
    widgets = [
      for i, w in local.dashboard_widgets : {
        type   = "metric"
        x      = (i % 3) * 8
        y      = floor(i / 3) * 6
        width  = 8
        height = 6
        properties = {
          title   = w.title
          region  = var.region
          stat    = w.stat
          period  = 60
          metrics = [[local.metrics_namespace, w.metric, "Environment", var.environment]]
        }
      }
    ]
  })
}
