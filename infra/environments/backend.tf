# Partial configuration: bucket, endpoint and locking come from envs/<env>.s3.tfbackend
# (terraform init -backend-config=envs/<env>.s3.tfbackend). One state bucket per account.
terraform {
  backend "s3" {}
}
