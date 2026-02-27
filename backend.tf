# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# Remote state storage with S3 and DynamoDB locking.
# This file is for reference - actual backend config is in each environment.
# =============================================================================

# Bootstrap resources for state management
# Run this once manually or via bootstrap script before using remote state.

# -----------------------------------------------------------------------------
# S3 Bucket for State
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name      = "${var.project_name}-terraform-state"
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "terraform-state"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state[0].arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# DynamoDB Table for Locking
# -----------------------------------------------------------------------------

resource "aws_dynamodb_table" "terraform_lock" {
  count = var.create_state_bucket ? 1 : 0

  name         = "${var.project_name}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.project_name}-terraform-lock"
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "terraform-state-lock"
  }
}

# -----------------------------------------------------------------------------
# KMS Key for State Encryption
# -----------------------------------------------------------------------------

resource "aws_kms_key" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name      = "${var.project_name}-terraform-state-key"
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "terraform-state-encryption"
  }
}

resource "aws_kms_alias" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  name          = "alias/${var.project_name}-terraform-state"
  target_key_id = aws_kms_key.terraform_state[0].key_id
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "create_state_bucket" {
  description = "Whether to create state bucket (bootstrap only)"
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "blueprint"
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].id : null
}

output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = var.create_state_bucket ? aws_dynamodb_table.terraform_lock[0].name : null
}

output "state_kms_key_arn" {
  description = "ARN of the KMS key for state encryption"
  value       = var.create_state_bucket ? aws_kms_key.terraform_state[0].arn : null
}
