# =============================================================================
# Compliance Module - Variables
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
# CloudTrail Configuration
# -----------------------------------------------------------------------------

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = ""
}

variable "cloudtrail_kms_key_arn" {
  description = "KMS key ARN for CloudTrail encryption"
  type        = string
  default     = ""
}

variable "cloudtrail_enable_insights" {
  description = "Enable CloudTrail Insights"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# AWS Config Configuration
# -----------------------------------------------------------------------------

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "config_s3_bucket_name" {
  description = "S3 bucket name for AWS Config"
  type        = string
  default     = ""
}

variable "config_delivery_frequency" {
  description = "Config snapshot delivery frequency"
  type        = string
  default     = "TwentyFour_Hours"
}

# -----------------------------------------------------------------------------
# Data Retention Configuration
# -----------------------------------------------------------------------------

variable "cloudwatch_logs_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

variable "s3_logs_retention_days" {
  description = "S3 logs retention in days"
  type        = number
  default     = 90
}

variable "s3_archive_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 365
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
