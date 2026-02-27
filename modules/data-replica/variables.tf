# =============================================================================
# Data Replica Module - Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Basic Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region_key" {
  description = "Region key for naming (e.g., eu_west_1)"
  type        = string
}

variable "aws_region" {
  description = "AWS region (e.g., eu-west-1)"
  type        = string
}

# -----------------------------------------------------------------------------
# Aurora Replica
# -----------------------------------------------------------------------------

variable "global_cluster_identifier" {
  description = "Aurora Global Cluster identifier to join"
  type        = string
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version (must match primary)"
  type        = string
  default     = "15.4"
}

variable "aurora_serverless_min_capacity" {
  description = "Minimum ACU capacity for Aurora Serverless v2"
  type        = number
  default     = 2
}

variable "aurora_serverless_max_capacity" {
  description = "Maximum ACU capacity for Aurora Serverless v2"
  type        = number
  default     = 64
}

variable "aurora_reader_count" {
  description = "Number of reader instances in the replica cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.aurora_reader_count >= 1 && var.aurora_reader_count <= 15
    error_message = "aurora_reader_count must be between 1 and 15 for replica clusters."
  }
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = false
}

variable "aurora_storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "aurora_kms_key_arn" {
  description = "KMS key ARN for encryption in this region (empty for AWS-managed key)"
  type        = string
  default     = ""
}

variable "aurora_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "aurora_enhanced_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  type        = number
  default     = 60
}

variable "aurora_master_secret_name" {
  description = "Name of the Secrets Manager secret (must be replicated to this region)"
  type        = string
}

# -----------------------------------------------------------------------------
# RDS Proxy
# -----------------------------------------------------------------------------

variable "rds_proxy_idle_client_timeout" {
  description = "Idle client timeout for RDS Proxy in seconds"
  type        = number
  default     = 1800
}

variable "rds_proxy_iam_auth" {
  description = "IAM authentication for client connections (DISABLED, ALLOWED, or REQUIRED)"
  type        = string
  default     = "DISABLED"

  validation {
    condition     = contains(["DISABLED", "ALLOWED", "REQUIRED"], var.rds_proxy_iam_auth)
    error_message = "rds_proxy_iam_auth must be DISABLED, ALLOWED, or REQUIRED."
  }
}

variable "rds_proxy_connection_borrow_timeout" {
  description = "Max seconds to wait for an available connection from the pool"
  type        = number
  default     = 10
}

# -----------------------------------------------------------------------------
# Network Configuration (from region module)
# -----------------------------------------------------------------------------

variable "private_subnet_ids" {
  description = "List of private subnet IDs in this region"
  type        = list(string)
}

variable "database_security_group_id" {
  description = "Security group ID for database access in this region"
  type        = string
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
