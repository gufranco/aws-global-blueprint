# =============================================================================
# Production Environment - Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "multiregion"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Domain name for Route53"
  type        = string
}

variable "create_hosted_zone" {
  description = "Whether to create Route53 hosted zone"
  type        = bool
  default     = false
}

variable "existing_hosted_zone_id" {
  description = "Existing Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "ecr_repositories" {
  description = "ECR repository names"
  type        = list(string)
  default     = ["api", "worker"]
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
}

variable "acm_certificate_arns" {
  description = "Map of region to ACM certificate ARN"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Region Configuration
# -----------------------------------------------------------------------------

variable "regions" {
  description = "Map of AWS regions"
  type = map(object({
    enabled     = bool
    aws_region  = string
    is_primary  = bool
    tier        = string
    cidr_block  = string
    ecs_api_min = number
    ecs_api_max = number
    enable_nat  = bool
  }))
}

# -----------------------------------------------------------------------------
# ECS Configuration
# -----------------------------------------------------------------------------

variable "use_fargate_spot" {
  description = "Use Fargate Spot for workers"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Database Configuration
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

variable "aurora_database_name" {
  description = "Aurora database name"
  type        = string
  default     = "app"
}

# -----------------------------------------------------------------------------
# Redis Configuration
# -----------------------------------------------------------------------------

variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.r6g.large"
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default = {
    Team = "platform"
  }
}
