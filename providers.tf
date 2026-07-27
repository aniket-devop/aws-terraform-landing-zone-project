# providers.tf
# Single AWS provider block. Region and default tags are driven by variables
# so the same code can be re-used across accounts/environments without edits.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}
