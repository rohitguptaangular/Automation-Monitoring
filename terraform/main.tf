# =============================================================
# main.tf
# PURPOSE: Entry point for Terraform. Tells Terraform:
#   1. Which cloud provider to use (AWS)
#   2. Which version of Terraform and the AWS plugin is needed
#   3. How to authenticate with AWS
# =============================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      # ~> 5.0 means "any 5.x version" — keeps us on major version 5
    }
  }
}

# ---------------------------------------------------------------
# AWS Provider Block
# Terraform uses this to make API calls to your AWS account.
# Authentication comes from AWS CLI credentials (~/.aws/credentials)
# which you set up via: aws configure
# ---------------------------------------------------------------
provider "aws" {
  region = var.aws_region

  # Apply these tags to EVERY resource Terraform creates.
  # This is best practice — helps with cost tracking and cleanup.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}
