environment = "dev"

# Initial image (public base). The CD pipeline overrides it with -var image=<registry>/traccar:<commit-sha>.
image = "traccar/traccar:6.17.0-alpine@sha256:b32d9346adf46df7c33c58577e17ad60f6feadd1f3cd87c876041f6c79317ef1"

web_port    = 8084
osmand_port = 5057

task_cpu      = 512
task_memory   = 1024
desired_count = 1

db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_backup_retention_days = 1
db_deletion_protection   = false
db_skip_final_snapshot   = true

log_retention_days    = 1
enable_backups        = false
backup_retention_days = 7
