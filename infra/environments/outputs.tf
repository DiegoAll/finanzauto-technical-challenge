output "web_url" {
  description = "Local URL of Traccar."
  value       = module.traccar.web_url
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.traccar.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.traccar.service_name
}

output "task_definition_arn" {
  description = "Current task definition revision."
  value       = module.traccar.task_definition_arn
}

output "db_address" {
  description = "Database endpoint address."
  value       = module.traccar.db_address
}

output "db_port" {
  description = "Database endpoint port."
  value       = module.traccar.db_port
}

output "db_secret_arn" {
  description = "ARN of the database password secret."
  value       = module.traccar.db_secret_arn
}

output "log_group_name" {
  description = "CloudWatch log group."
  value       = module.traccar.log_group_name
}

output "backup_bucket" {
  description = "S3 bucket for database backups."
  value       = module.traccar.backup_bucket
}
