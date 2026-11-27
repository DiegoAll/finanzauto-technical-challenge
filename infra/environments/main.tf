# Single root configuration for all environments: same code, different
# variables (envs/<env>.tfvars) and separate state (envs/<env>.s3.tfbackend).
module "traccar" {
  source = "../modules/traccar-stack"

  environment = var.environment
  region      = var.region

  image                     = var.image
  web_port                  = var.web_port
  osmand_port               = var.osmand_port
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory
  desired_count             = var.desired_count
  inject_db_password_as_env = var.inject_db_password_as_env

  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_backup_retention_days = var.db_backup_retention_days
  db_deletion_protection   = var.db_deletion_protection
  db_skip_final_snapshot   = var.db_skip_final_snapshot

  log_retention_days    = var.log_retention_days
  enable_backups        = var.enable_backups
  backup_retention_days = var.backup_retention_days
}
