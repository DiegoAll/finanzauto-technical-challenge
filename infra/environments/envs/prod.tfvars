environment = "prod"

# Initial image (public base). The CD pipeline overrides it with -var image=<registry>/traccar:<commit-sha>.
image = "traccar/traccar:6.17.0-alpine@sha256:b32d9346adf46df7c33c58577e17ad60f6feadd1f3cd87c876041f6c79317ef1"

web_port    = 8082
osmand_port = 5055

task_cpu      = 1024
task_memory   = 2048
desired_count = 1

db_instance_class        = "db.t3.small"
db_allocated_storage     = 20
db_backup_retention_days = 7
db_deletion_protection   = true
db_skip_final_snapshot   = false

log_retention_days    = 30
enable_backups        = true
backup_retention_days = 30
