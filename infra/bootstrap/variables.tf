variable "region" {
  description = "AWS region used for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "aws_endpoint" {
  description = "AWS API endpoint. Floci locally; leave null for real AWS."
  type        = string
  default     = "http://localhost:4566"
}
