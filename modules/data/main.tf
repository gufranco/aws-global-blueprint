# =============================================================================
# Data Module - Main Configuration
# =============================================================================
# This module manages global data stores:
# - Aurora Global Database (PostgreSQL)
# - DynamoDB Global Tables
# - ElastiCache Global Datastore (Redis)
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

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Filter enabled regions
  enabled_regions = {
    for key, region in var.regions : key => region
    if region.enabled
  }

  # Get primary region
  primary_region_key = [
    for key, region in var.regions : key
    if region.is_primary && region.enabled
  ][0]

  # Common tags
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "data"
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
