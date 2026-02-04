# =============================================================================
# Data Retention Policies
# =============================================================================

# -----------------------------------------------------------------------------
# S3 Lifecycle Rules (applied via bucket configuration)
# -----------------------------------------------------------------------------

# These policies are typically applied to individual buckets.
# This file provides reusable lifecycle rule configurations.

locals {
  standard_lifecycle_rules = [
    {
      id      = "transition-to-ia"
      enabled = true
      prefix  = ""

      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
    },
    {
      id      = "transition-to-glacier"
      enabled = true
      prefix  = ""

      transition = [
        {
          days          = var.s3_archive_days
          storage_class = "GLACIER"
        }
      ]
    },
    {
      id      = "expire-old-versions"
      enabled = true
      prefix  = ""

      noncurrent_version_expiration = {
        days = 90
      }
    },
    {
      id      = "delete-incomplete-uploads"
      enabled = true
      prefix  = ""

      abort_incomplete_multipart_upload_days = 7
    }
  ]

  logs_lifecycle_rules = [
    {
      id      = "expire-logs"
      enabled = true
      prefix  = ""

      expiration = {
        days = var.s3_logs_retention_days
      }
    }
  ]
}

# -----------------------------------------------------------------------------
# CloudWatch Logs Retention
# -----------------------------------------------------------------------------

# Note: These are applied to log groups created by other modules.
# This resource sets default retention for the account.

resource "aws_cloudwatch_log_group" "retention_policy_example" {
  count = var.enable_config ? 0 : 0 # Disabled - just for documentation

  name              = "${local.name_prefix}-retention-example"
  retention_in_days = var.cloudwatch_logs_retention_days

  tags = merge(local.common_tags, var.tags)
}

# -----------------------------------------------------------------------------
# DynamoDB TTL Configuration (applied via table configuration)
# -----------------------------------------------------------------------------

# TTL is configured on individual DynamoDB tables.
# Typical TTL attributes:
# - sessions.ttl: Session expiration
# - events.ttl: Event retention
# - cache.ttl: Cache expiration

# -----------------------------------------------------------------------------
# RDS Automated Backups Retention
# -----------------------------------------------------------------------------

# RDS backup retention is configured in the data module.
# Default: 7 days for dev, 35 days for prod

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "standard_lifecycle_rules" {
  description = "Standard S3 lifecycle rules for reuse"
  value       = local.standard_lifecycle_rules
}

output "logs_lifecycle_rules" {
  description = "S3 lifecycle rules for log buckets"
  value       = local.logs_lifecycle_rules
}

output "recommended_retention_periods" {
  description = "Recommended retention periods by data type"
  value = {
    application_logs = "${var.cloudwatch_logs_retention_days} days"
    audit_logs       = "365 days (compliance)"
    session_data     = "24 hours"
    analytics_events = "90 days"
    backups          = "35 days (prod), 7 days (dev)"
    archives         = "${var.s3_archive_days} days before Glacier"
  }
}
