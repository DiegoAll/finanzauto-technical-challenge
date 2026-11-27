# Credentials come from the environment: AWS_ACCESS_KEY_ID selects the Floci account
# (set by the Makefile per ENV) and AWS_SECRET_ACCESS_KEY from .env.
provider "aws" {
  region = var.region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  # Every service used by the configuration must point at the emulator.
  endpoints {
    cloudwatch     = var.aws_endpoint
    ec2            = var.aws_endpoint
    ecs            = var.aws_endpoint
    iam            = var.aws_endpoint
    logs           = var.aws_endpoint
    rds            = var.aws_endpoint
    s3             = var.aws_endpoint
    secretsmanager = var.aws_endpoint
    sns            = var.aws_endpoint
    sts            = var.aws_endpoint
  }

  default_tags {
    tags = {
      Project     = "avl-traccar"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
