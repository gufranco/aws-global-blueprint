# =============================================================================
# Observability Module - Main Configuration
# =============================================================================
# This module manages observability resources:
# - CloudWatch Dashboards
# - CloudWatch Alarms
# - Custom Metrics
# - X-Ray Tracing
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
    Module      = "observability"
  }
}

data "aws_region" "current" {}
