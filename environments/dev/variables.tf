# =============================================================================
# Development Environment - Variables
# =============================================================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "blueprint"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Domain name for Route53"
  type        = string
  default     = ""
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

variable "enable_global_accelerator" {
  description = "Enable Global Accelerator"
  type        = bool
  default     = false # Disabled for dev to save costs
}

variable "ecr_repositories" {
  description = "ECR repository names"
  type        = list(string)
  default     = ["api", "worker"]
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "use_localstack" {
  description = "Use LocalStack for local development"
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
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
  default = {
    us_east_1 = {
      enabled     = true
      aws_region  = "us-east-1"
      is_primary  = true
      tier        = "primary"
      cidr_block  = "10.0.0.0/16"
      ecs_api_min = 1
      ecs_api_max = 2
      enable_nat  = false # Disabled for dev to save costs
    }
  }
}

# -----------------------------------------------------------------------------
# ECS Configuration
# -----------------------------------------------------------------------------

variable "ecs_api_desired" {
  description = "Desired number of API tasks"
  type        = number
  default     = 1
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot for workers"
  type        = bool
  default     = false # Standard Fargate for dev stability
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_serverless_min_capacity" {
  description = "Minimum ACU capacity for Aurora Serverless v2"
  type        = number
  default     = 0.5
}

variable "aurora_serverless_max_capacity" {
  description = "Maximum ACU capacity for Aurora Serverless v2"
  type        = number
  default     = 4
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
  default     = "cache.t3.micro" # Smaller for dev
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default = {
    Team = "development"
  }
}
