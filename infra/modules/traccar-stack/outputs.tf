output "web_url" {
  description = "Local URL of Traccar for this environment."
  value       = "http://localhost:${var.web_port}"
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "Current task definition revision (used for rollback)."
  value       = aws_ecs_task_definition.app.arn
}

output "db_address" {
  description = "Database endpoint address."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Database endpoint port."
  value       = aws_db_instance.this.port
}

output "db_secret_arn" {
  description = "ARN of the database password secret."
  value       = aws_secretsmanager_secret.db.arn
}

output "log_group_name" {
  description = "CloudWatch log group for Traccar."
  value       = aws_cloudwatch_log_group.app.name
}

output "backup_bucket" {
  description = "S3 bucket for database backups (null when backups are disabled)."
  value       = var.enable_backups ? aws_s3_bucket.backups[0].bucket : null
}
