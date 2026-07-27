# backend.tf
# Remote state in S3 with DynamoDB locking.
#
# IMPORTANT (chicken-and-egg problem):
# Terraform cannot create the bucket/table it is about to use as its own
# backend in the same run. Bootstrap them first with local state, either via
# the AWS CLI or the `bootstrap/` config described in the README, THEN
# uncomment this block, fill in your bucket/table names, and run:
#
#   terraform init -migrate-state
#
# Values below are placeholders — replace before use. Consider passing
# bucket/key/region via `-backend-config` flags or a partial backend config
# per environment instead of hardcoding, if you manage multiple environments
# from this same code.

# terraform {
#   backend "s3" {
#     bucket         = "aniket-devops-tfstate-<unique-suffix>"
#     key            = "aws-landing-zone/dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "aniket-devops-tf-locks"
#     encrypt        = true
#   }
# }
