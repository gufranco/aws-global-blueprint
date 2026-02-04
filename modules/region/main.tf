# =============================================================================
# Region Module - Main Configuration
# =============================================================================
# This module manages all resources within a single AWS region:
# - VPC and networking (subnets, NAT, security groups)
# - ECS Fargate cluster (API and Worker services)
# - Application Load Balancer
# - SQS queues and SNS topics
# - Lambda functions
# - CloudWatch logs and metrics
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
  name_prefix = "${var.project_name}-${var.environment}-${var.region_key}"

  # Availability zones for this region
  availability_zones = [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]

  # Calculate subnet CIDRs from the region CIDR
  # Assumes /16 CIDR, splits into /24 subnets
  cidr_parts  = split(".", var.cidr_block)
  cidr_prefix = "${local.cidr_parts[0]}.${local.cidr_parts[1]}"
  public_subnet_cidrs = [
    "${local.cidr_prefix}.0.0/24",
    "${local.cidr_prefix}.1.0/24"
  ]
  private_subnet_cidrs = [
    "${local.cidr_prefix}.10.0/24",
    "${local.cidr_prefix}.11.0/24"
  ]

  # Common tags for all resources in this region
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Region      = var.aws_region
    RegionKey   = var.region_key
    Tier        = var.tier
    IsPrimary   = var.is_primary
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
