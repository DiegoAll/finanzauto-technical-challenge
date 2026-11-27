locals {
  name = "avl-traccar-${var.environment}"

  db_name     = "traccar"
  db_username = "traccar"
  db_url      = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${local.db_name}"

  app_environment = [
    { name = "CONFIG_USE_ENVIRONMENT_VARIABLES", value = "true" },
    { name = "DATABASE_DRIVER", value = "org.postgresql.Driver" },
    { name = "DATABASE_URL", value = local.db_url },
    { name = "DATABASE_USER", value = local.db_username },
    { name = "LOGGER_CONSOLE", value = "true" },
    { name = "WEB_PORT", value = tostring(var.web_port) },
    { name = "OSMAND_PORT", value = tostring(var.osmand_port) },
  ]

  # Preferred: ECS injects the password from Secrets Manager at task start.
  # Fallback (emulator limitation): plain environment variable, documented as a risk.
  db_password_env = var.inject_db_password_as_env ? [
    { name = "DATABASE_PASSWORD", value = random_password.db.result },
  ] : []

  db_password_secret = var.inject_db_password_as_env ? [] : [
    { name = "DATABASE_PASSWORD", valueFrom = aws_secretsmanager_secret.db.arn },
  ]
}

# --- Network (default VPC; a dedicated VPC is the real-AWS improvement) -------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Traccar tasks"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "app_web" {
  security_group_id = aws_security_group.app.id
  description       = "Traccar web UI and API"
  ip_protocol       = "tcp"
  from_port         = var.web_port
  to_port           = var.web_port
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_osmand" {
  security_group_id = aws_security_group.app.id
  description       = "OsmAnd GPS protocol"
  ip_protocol       = "tcp"
  from_port         = var.osmand_port
  to_port           = var.osmand_port
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound to database and AWS APIs"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "Traccar database"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from Traccar tasks only"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

# --- Database credentials ------------------------------------------------------

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/db-password"
  description             = "Traccar database password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = random_password.db.result
}

# --- Database ------------------------------------------------------------------

resource "aws_db_instance" "this" {
  identifier     = "${local.name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_encrypted = true

  db_name  = local.db_name
  username = local.db_username
  password = random_password.db.result

  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period   = var.db_backup_retention_days
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name}-db-final"
}

# --- Logs ----------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
}

# --- IAM: execution role (pull image, write logs, read the DB secret) ----------

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db.arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "read-db-secret"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

# --- ECS -----------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name = local.name
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([
    {
      name      = "traccar"
      image     = var.image
      essential = true

      portMappings = [
        { containerPort = var.web_port, hostPort = var.web_port, protocol = "tcp" },
        { containerPort = var.osmand_port, hostPort = var.osmand_port, protocol = "tcp" },
      ]

      environment = concat(local.app_environment, local.db_password_env)
      secrets     = local.db_password_secret

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "traccar"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1:${var.web_port}/api/server || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90
      }
    }
  ])

  depends_on = [aws_secretsmanager_secret_version.db]
}

resource "aws_ecs_service" "app" {
  name            = "traccar"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Stable host ports allow one task per port: stop the old task before starting
  # the new one (short gap during deploys/rollbacks, documented).
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }
}

# --- Backups (Prod) ------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  count  = var.enable_backups ? 1 : 0
  bucket = "${local.name}-backups"
}

resource "aws_s3_bucket_versioning" "backups" {
  count  = var.enable_backups ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  count  = var.enable_backups ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  count  = var.enable_backups ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  count  = var.enable_backups ? 1 : 0
  bucket = aws_s3_bucket.backups[0].id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.backup_retention_days
    }
  }
}
