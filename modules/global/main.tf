# =============================================================================
# Global Module - Main Configuration
# =============================================================================
# This module manages global resources that span multiple regions:
# - AWS Global Accelerator for global traffic routing
# - Route53 for DNS management and health checks
# - ECR for container image registry
# - CloudFront for CDN (optional)
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

  primary_region = var.regions[local.primary_region_key]

  # Common tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "global"
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}
