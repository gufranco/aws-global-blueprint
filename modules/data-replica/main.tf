# =============================================================================
# Data Replica Module
# =============================================================================
# Deploys an Aurora Global Database replica cluster with a local RDS Proxy
# in a secondary region. Each instance of this module receives a provider
# for its target region.
#
# The replica cluster is read-only. Writes must go to the primary region.
# The local RDS Proxy eliminates cross-region latency for read queries.
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
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Look up the replicated secret in this region
data "aws_secretsmanager_secret" "aurora_master" {
  name = var.aurora_master_secret_name
}
