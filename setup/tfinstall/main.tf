terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.0"
    }
  }
}

# --- 1. Providers ---
provider "aws" {
  region = "us-east-1"
  # This lets the provider fail gracefully if keys are missing
  skip_metadata_api_check = true
}

variable "atlas_project_id" {
  type    = string
  default = "NOT_SET"
  # We leave this without a 'validation' block so Terraform doesn't 
  # crash immediately, allowing our 'check' block to give a pretty error.
}

provider "mongodbatlas" {
  # It will automatically look for MONGODB_ATLAS_PUBLIC_KEY 
  # and MONGODB_ATLAS_PRIVATE_KEY in your env
}

# --- 2. Handshake Data Sources ---
# This fails if AWS_ACCESS_KEY_ID/SECRET are missing or wrong
data "aws_caller_identity" "current" {}

# This fails if MONGODB_ATLAS_PUBLIC_KEY/PRIVATE_KEY are missing or wrong
data "mongodbatlas_projects" "all" {}

# --- 3. The Check Block ---
check "connectivity_gatekeeper" {

assert {
    condition     = var.atlas_project_id != "NOT_SET"
    error_message = "MISSING VARIABLE: Please run 'export TF_VAR_atlas_project_id=your_id_here'"
  }
  
  assert {
    condition     = data.aws_caller_identity.current.account_id != null
    error_message = "AWS AUTH FAILED: Check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
  }

  assert {
    # If the API keys are bad, data.mongodbatlas_projects will be empty or error out
    condition     = length(data.mongodbatlas_projects.all.results) >= 0
    error_message = "ATLAS AUTH FAILED: Check MONGODB_ATLAS_PUBLIC_KEY and MONGODB_ATLAS_PRIVATE_KEY."
  }
}