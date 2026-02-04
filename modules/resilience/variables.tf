# =============================================================================
# Resilience Module - Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# -----------------------------------------------------------------------------
# Backup Configuration
# -----------------------------------------------------------------------------

variable "enable_backup" {
  description = "Enable AWS Backup"
  type        = bool
  default     = true
}

variable "backup_schedule" {
  description = "Backup schedule (cron expression)"
  type        = string
  default     = "cron(0 5 ? * * *)" # Daily at 5 AM UTC
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 35
}

variable "backup_cross_region" {
  description = "Enable cross-region backup copy"
  type        = bool
  default     = true
}

variable "backup_cross_region_destination" {
  description = "Destination region for cross-region backup"
  type        = string
  default     = "eu-west-1"
}

variable "rds_cluster_arns" {
  description = "List of RDS cluster ARNs to backup"
  type        = list(string)
  default     = []
}

variable "dynamodb_table_arns" {
  description = "List of DynamoDB table ARNs to backup"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to backup"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# FIS Configuration
# -----------------------------------------------------------------------------

variable "enable_fis" {
  description = "Enable Fault Injection Simulator"
  type        = bool
  default     = false
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN for FIS experiments"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name for FIS experiments"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
