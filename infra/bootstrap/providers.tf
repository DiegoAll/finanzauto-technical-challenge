# Credentials come from the environment: AWS_ACCESS_KEY_ID selects the Floci account
# (12-digit ID per environment, set by the Makefile) and AWS_SECRET_ACCESS_KEY from .env.
provider "aws" {
  region = var.region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = var.aws_endpoint
    sts = var.aws_endpoint
  }

  default_tags {
    tags = {
      Project     = "avl-traccar"
      Environment = local.environment
      ManagedBy   = "terraform"
      Component   = "state-bootstrap"
    }
  }
}
