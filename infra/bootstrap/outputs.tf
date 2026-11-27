output "state_bucket" {
  description = "Name of the Terraform state bucket for this environment."
  value       = aws_s3_bucket.state.bucket
}

output "environment" {
  description = "Environment (workspace) this bucket belongs to."
  value       = local.environment
}
