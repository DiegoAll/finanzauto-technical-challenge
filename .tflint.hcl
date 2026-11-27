# tflint configuration shared by every Terraform root and module.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules (invalid instance types, deprecated arguments, etc.). Pinned version; tflint verifies the plugin signature.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
