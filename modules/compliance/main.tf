# =============================================================================
# Compliance Module
# =============================================================================
# This module manages compliance resources:
# - CloudTrail
# - AWS Config
# - Data retention policies
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "compliance"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
