variable "environment" {
  description = "Environment name (dev, uat, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be dev, uat or prod."
  }
}

variable "region" {
  description = "AWS region, used by the awslogs driver."
  type        = string
  default     = "us-east-1"
}

# --- Application -------------------------------------------------------------

variable "image" {
  description = "Traccar container image, pinned by tag/SHA or digest. Promoted unchanged across environments."
  type        = string
}

variable "web_port" {
  description = "Traccar web/API port. Differs per environment only to avoid host port collisions in the local emulator."
  type        = number
}

variable "osmand_port" {
  description = "OsmAnd protocol port (GPS devices / simulator)."
  type        = number
}

variable "task_cpu" {
  description = "Task CPU units."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of Traccar tasks."
  type        = number
  default     = 1
}

variable "inject_db_password_as_env" {
  description = "Fallback if the emulator does not inject ECS 'secrets': pass the password as a plain environment variable. Keep false in real AWS."
  type        = bool
  default     = false
}

# --- Database ----------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_backup_retention_days" {
  description = "Automated RDS backup retention in days."
  type        = number
  default     = 1
}

variable "db_deletion_protection" {
  description = "Protect the database from deletion."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when the database is destroyed."
  type        = bool
  default     = true
}

# --- Operations --------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch Logs retention for Traccar logs."
  type        = number
  default     = 1
}

variable "enable_backups" {
  description = "Create the S3 bucket for logical database backups (pg_dump)."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days to keep backup objects before expiring them."
  type        = number
  default     = 7
}
