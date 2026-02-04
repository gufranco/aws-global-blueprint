# =============================================================================
# Observability Module - Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# -----------------------------------------------------------------------------
# ECS Configuration
# -----------------------------------------------------------------------------

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_api_service_name" {
  description = "ECS API service name"
  type        = string
}

variable "ecs_worker_service_name" {
  description = "ECS Worker service name"
  type        = string
}

# -----------------------------------------------------------------------------
# ALB Configuration
# -----------------------------------------------------------------------------

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix"
  type        = string
}

# -----------------------------------------------------------------------------
# Alarm Configuration
# -----------------------------------------------------------------------------

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
}

variable "api_cpu_threshold" {
  description = "CPU threshold for API service alarm"
  type        = number
  default     = 80
}

variable "api_memory_threshold" {
  description = "Memory threshold for API service alarm"
  type        = number
  default     = 80
}

variable "error_rate_threshold" {
  description = "Error rate threshold (percentage)"
  type        = number
  default     = 5
}

variable "latency_p99_threshold" {
  description = "P99 latency threshold in milliseconds"
  type        = number
  default     = 1000
}

variable "dlq_message_threshold" {
  description = "DLQ message count threshold"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# SQS Configuration
# -----------------------------------------------------------------------------

variable "sqs_queue_names" {
  description = "List of SQS queue names to monitor"
  type        = list(string)
  default     = []
}

variable "sqs_dlq_name" {
  description = "DLQ name to monitor"
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
