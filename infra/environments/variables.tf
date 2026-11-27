variable "environment" {
  description = "Environment name (dev, uat, prod)."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "aws_endpoint" {
  description = "AWS API endpoint (Floci)."
  type        = string
  default     = "http://localhost:4566"
}

variable "image" {
  description = "Traccar image. The CD pipeline overrides it with the commit SHA tag to promote the same image."
  type        = string
}

variable "web_port" {
  description = "Traccar web/API port."
  type        = number
}

variable "osmand_port" {
  description = "OsmAnd protocol port."
  type        = number
}

variable "task_cpu" {
  description = "Task CPU units."
  type        = number
}

variable "task_memory" {
  description = "Task memory in MiB."
  type        = number
}

variable "desired_count" {
  description = "Number of Traccar tasks."
  type        = number
}

variable "inject_db_password_as_env" {
  description = "Emulator fallback: pass the DB password as an environment variable instead of ECS secrets."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB."
  type        = number
}

variable "db_backup_retention_days" {
  description = "Automated RDS backup retention in days."
  type        = number
}

variable "db_deletion_protection" {
  description = "Protect the database from deletion."
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy."
  type        = bool
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention."
  type        = number
}

variable "enable_backups" {
  description = "Create the S3 bucket for logical database backups."
  type        = bool
}

variable "backup_retention_days" {
  description = "Days to keep backup objects."
  type        = number
}
