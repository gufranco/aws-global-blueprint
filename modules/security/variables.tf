# =============================================================================
# Security Module - Variables
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
# WAF Configuration
# -----------------------------------------------------------------------------

variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = true
}

variable "waf_scope" {
  description = "WAF scope (REGIONAL or CLOUDFRONT)"
  type        = string
  default     = "REGIONAL"
}

variable "waf_rate_limit" {
  description = "Rate limit per IP (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "waf_blocked_countries" {
  description = "List of country codes to block"
  type        = list(string)
  default     = []
}

variable "waf_allowed_ips" {
  description = "List of allowed IP addresses (CIDR notation)"
  type        = list(string)
  default     = []
}

variable "alb_arn" {
  description = "ALB ARN to associate WAF with"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# KMS Configuration
# -----------------------------------------------------------------------------

variable "enable_kms" {
  description = "Enable KMS key creation"
  type        = bool
  default     = true
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "kms_enable_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# GuardDuty Configuration
# -----------------------------------------------------------------------------

variable "enable_guardduty" {
  description = "Enable GuardDuty"
  type        = bool
  default     = true
}

variable "guardduty_finding_publishing_frequency" {
  description = "GuardDuty finding publishing frequency"
  type        = string
  default     = "FIFTEEN_MINUTES"
}

# -----------------------------------------------------------------------------
# Security Hub Configuration
# -----------------------------------------------------------------------------

variable "enable_security_hub" {
  description = "Enable Security Hub"
  type        = bool
  default     = true
}

variable "security_hub_standards" {
  description = "Security Hub standards to enable"
  type        = list(string)
  default = [
    "aws-foundational-security-best-practices/v/1.0.0",
    "cis-aws-foundations-benchmark/v/1.4.0"
  ]
}

# -----------------------------------------------------------------------------
# VPC Endpoints Configuration
# -----------------------------------------------------------------------------

variable "enable_vpc_endpoints" {
  description = "Enable VPC Endpoints"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID for VPC Endpoints"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for VPC Endpoints"
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC Endpoints"
  type        = string
  default     = ""
}

variable "route_table_ids" {
  description = "Route table IDs for S3/DynamoDB gateway endpoints"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
