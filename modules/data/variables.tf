# =============================================================================
# Data Module - Variables
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

variable "regions" {
  description = "Map of AWS regions with their configuration"
  type = map(object({
    enabled    = bool
    aws_region = string
    is_primary = bool
    tier       = string
  }))
}

# -----------------------------------------------------------------------------
# Aurora Global Database
# -----------------------------------------------------------------------------

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "aurora_instances_per_cluster" {
  description = "Number of instances per Aurora cluster"
  type        = number
  default     = 2
}

variable "aurora_database_name" {
  description = "Initial database name"
  type        = string
  default     = "app"
}

variable "aurora_master_username" {
  description = "Master username for Aurora"
  type        = string
  default     = "postgres"
}

variable "aurora_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "aurora_preferred_backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "aurora_preferred_maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "aurora_skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = false
}

variable "aurora_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "aurora_storage_encrypted" {
  description = "Enable storage encryption"
  type        = bool
  default     = true
}

variable "aurora_kms_key_arn" {
  description = "KMS key ARN for Aurora encryption"
  type        = string
  default     = ""
}

variable "aurora_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "aurora_enhanced_monitoring_interval" {
  description = "Enhanced monitoring interval (0 to disable)"
  type        = number
  default     = 60
}

# -----------------------------------------------------------------------------
# DynamoDB Global Tables
# -----------------------------------------------------------------------------

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (if PROVISIONED)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (if PROVISIONED)"
  type        = number
  default     = 5
}

variable "dynamodb_point_in_time_recovery" {
  description = "Enable Point-in-Time Recovery"
  type        = bool
  default     = true
}

variable "dynamodb_ttl_enabled" {
  description = "Enable TTL for sessions table"
  type        = bool
  default     = true
}

variable "dynamodb_ttl_attribute" {
  description = "TTL attribute name"
  type        = string
  default     = "expiresAt"
}

# -----------------------------------------------------------------------------
# ElastiCache (Redis)
# -----------------------------------------------------------------------------

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.r6g.large"
}

variable "redis_num_cache_clusters" {
  description = "Number of cache clusters (nodes)"
  type        = number
  default     = 2
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "redis_snapshot_window" {
  description = "Daily time range for snapshots (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "redis_maintenance_window" {
  description = "Weekly maintenance window (UTC)"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover"
  type        = bool
  default     = true
}

variable "redis_at_rest_encryption_enabled" {
  description = "Enable at-rest encryption"
  type        = bool
  default     = true
}

variable "redis_transit_encryption_enabled" {
  description = "Enable in-transit encryption"
  type        = bool
  default     = true
}

variable "redis_auth_token" {
  description = "Auth token for Redis (if transit encryption enabled)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Network Configuration (from region module)
# -----------------------------------------------------------------------------

variable "vpc_ids" {
  description = "Map of region key to VPC ID"
  type        = map(string)
  default     = {}
}

variable "private_subnet_ids" {
  description = "Map of region key to list of private subnet IDs"
  type        = map(list(string))
  default     = {}
}

variable "database_security_group_ids" {
  description = "Map of region key to database security group ID"
  type        = map(string)
  default     = {}
}

variable "redis_security_group_ids" {
  description = "Map of region key to Redis security group ID"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
