# =============================================================================
# Production Environment
# =============================================================================
# This is the main entry point for the production environment.
# It instantiates all modules with production-grade configuration.
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration - MUST be configured for production
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

# Primary region provider
provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# EU West 1 provider
provider "aws" {
  region = "eu-west-1"
  alias  = "eu_west_1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# AP Northeast 1 provider
provider "aws" {
  region = "ap-northeast-1"
  alias  = "ap_northeast_1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# SA East 1 provider
provider "aws" {
  region = "sa-east-1"
  alias  = "sa_east_1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Default provider (primary region)
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  enabled_regions = {
    for key, region in var.regions : key => region
    if region.enabled
  }
}

# -----------------------------------------------------------------------------
# Global Module (uses primary region provider)
# -----------------------------------------------------------------------------

module "global" {
  source = "../../modules/global"

  project_name              = var.project_name
  environment               = var.environment
  domain_name               = var.domain_name
  create_hosted_zone        = var.create_hosted_zone
  existing_hosted_zone_id   = var.existing_hosted_zone_id
  regions                   = var.regions
  enable_global_accelerator = true
  ecr_repositories          = var.ecr_repositories

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Region Modules
# -----------------------------------------------------------------------------

# US East 1 (Primary)
module "region_us_east_1" {
  source = "../../modules/region"
  count  = lookup(var.regions, "us_east_1", { enabled = false }).enabled ? 1 : 0

  providers = {
    aws = aws.us_east_1
  }

  project_name = var.project_name
  environment  = var.environment
  aws_region   = "us-east-1"
  region_key   = "us_east_1"
  is_primary   = var.regions["us_east_1"].is_primary
  tier         = var.regions["us_east_1"].tier
  cidr_block   = var.regions["us_east_1"].cidr_block
  enable_nat   = var.regions["us_east_1"].enable_nat

  ecs_api_min      = var.regions["us_east_1"].ecs_api_min
  ecs_api_max      = var.regions["us_east_1"].ecs_api_max
  use_fargate_spot = var.use_fargate_spot

  api_image    = "${module.global.ecr_repository_urls["api"]}:${var.image_tag}"
  worker_image = "${module.global.ecr_repository_urls["worker"]}:${var.image_tag}"

  acm_certificate_arn = var.acm_certificate_arns["us_east_1"]
  domain_name         = var.domain_name
  route53_zone_id     = module.global.route53_zone_id

  global_accelerator_endpoint_group_arn = module.global.global_accelerator_endpoint_groups["us_east_1"]

  database_endpoint      = module.data.aurora_primary_endpoint
  database_read_endpoint = module.data.aurora_primary_reader_endpoint
  database_port          = 5432
  database_name          = var.aurora_database_name
  database_secret_arn    = module.data.aurora_master_secret_arn

  redis_endpoint = module.data.redis_primary_endpoint
  redis_port     = 6379

  tags = var.tags
}

# EU West 1 (Secondary)
module "region_eu_west_1" {
  source = "../../modules/region"
  count  = lookup(var.regions, "eu_west_1", { enabled = false }).enabled ? 1 : 0

  providers = {
    aws = aws.eu_west_1
  }

  project_name = var.project_name
  environment  = var.environment
  aws_region   = "eu-west-1"
  region_key   = "eu_west_1"
  is_primary   = var.regions["eu_west_1"].is_primary
  tier         = var.regions["eu_west_1"].tier
  cidr_block   = var.regions["eu_west_1"].cidr_block
  enable_nat   = var.regions["eu_west_1"].enable_nat

  ecs_api_min      = var.regions["eu_west_1"].ecs_api_min
  ecs_api_max      = var.regions["eu_west_1"].ecs_api_max
  use_fargate_spot = var.use_fargate_spot

  api_image    = "${module.global.ecr_repository_urls["api"]}:${var.image_tag}"
  worker_image = "${module.global.ecr_repository_urls["worker"]}:${var.image_tag}"

  acm_certificate_arn = var.acm_certificate_arns["eu_west_1"]
  domain_name         = var.domain_name
  route53_zone_id     = module.global.route53_zone_id

  global_accelerator_endpoint_group_arn = module.global.global_accelerator_endpoint_groups["eu_west_1"]

  # Read-only in secondary regions
  database_endpoint      = module.data.aurora_primary_reader_endpoint
  database_read_endpoint = module.data.aurora_primary_reader_endpoint
  database_port          = 5432
  database_name          = var.aurora_database_name
  database_secret_arn    = module.data.aurora_master_secret_arn

  redis_endpoint = module.data.redis_primary_endpoint
  redis_port     = 6379

  tags = var.tags
}

# AP Northeast 1 (Secondary)
module "region_ap_northeast_1" {
  source = "../../modules/region"
  count  = lookup(var.regions, "ap_northeast_1", { enabled = false }).enabled ? 1 : 0

  providers = {
    aws = aws.ap_northeast_1
  }

  project_name = var.project_name
  environment  = var.environment
  aws_region   = "ap-northeast-1"
  region_key   = "ap_northeast_1"
  is_primary   = var.regions["ap_northeast_1"].is_primary
  tier         = var.regions["ap_northeast_1"].tier
  cidr_block   = var.regions["ap_northeast_1"].cidr_block
  enable_nat   = var.regions["ap_northeast_1"].enable_nat

  ecs_api_min      = var.regions["ap_northeast_1"].ecs_api_min
  ecs_api_max      = var.regions["ap_northeast_1"].ecs_api_max
  use_fargate_spot = var.use_fargate_spot

  api_image    = "${module.global.ecr_repository_urls["api"]}:${var.image_tag}"
  worker_image = "${module.global.ecr_repository_urls["worker"]}:${var.image_tag}"

  acm_certificate_arn = var.acm_certificate_arns["ap_northeast_1"]
  domain_name         = var.domain_name
  route53_zone_id     = module.global.route53_zone_id

  global_accelerator_endpoint_group_arn = module.global.global_accelerator_endpoint_groups["ap_northeast_1"]

  database_endpoint      = module.data.aurora_primary_reader_endpoint
  database_read_endpoint = module.data.aurora_primary_reader_endpoint
  database_port          = 5432
  database_name          = var.aurora_database_name
  database_secret_arn    = module.data.aurora_master_secret_arn

  redis_endpoint = module.data.redis_primary_endpoint
  redis_port     = 6379

  tags = var.tags
}

# SA East 1 (Tertiary)
module "region_sa_east_1" {
  source = "../../modules/region"
  count  = lookup(var.regions, "sa_east_1", { enabled = false }).enabled ? 1 : 0

  providers = {
    aws = aws.sa_east_1
  }

  project_name = var.project_name
  environment  = var.environment
  aws_region   = "sa-east-1"
  region_key   = "sa_east_1"
  is_primary   = var.regions["sa_east_1"].is_primary
  tier         = var.regions["sa_east_1"].tier
  cidr_block   = var.regions["sa_east_1"].cidr_block
  enable_nat   = var.regions["sa_east_1"].enable_nat

  ecs_api_min      = var.regions["sa_east_1"].ecs_api_min
  ecs_api_max      = var.regions["sa_east_1"].ecs_api_max
  use_fargate_spot = var.use_fargate_spot

  api_image    = "${module.global.ecr_repository_urls["api"]}:${var.image_tag}"
  worker_image = "${module.global.ecr_repository_urls["worker"]}:${var.image_tag}"

  acm_certificate_arn = var.acm_certificate_arns["sa_east_1"]
  domain_name         = var.domain_name
  route53_zone_id     = module.global.route53_zone_id

  global_accelerator_endpoint_group_arn = module.global.global_accelerator_endpoint_groups["sa_east_1"]

  database_endpoint      = module.data.aurora_primary_reader_endpoint
  database_read_endpoint = module.data.aurora_primary_reader_endpoint
  database_port          = 5432
  database_name          = var.aurora_database_name
  database_secret_arn    = module.data.aurora_master_secret_arn

  redis_endpoint = module.data.redis_primary_endpoint
  redis_port     = 6379

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Data Module
# -----------------------------------------------------------------------------

module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment
  regions      = var.regions

  # Aurora configuration
  aurora_engine_version      = var.aurora_engine_version
  aurora_instance_class      = var.aurora_instance_class
  aurora_database_name       = var.aurora_database_name
  aurora_skip_final_snapshot = false
  aurora_deletion_protection = true

  # DynamoDB configuration
  dynamodb_billing_mode           = "PAY_PER_REQUEST"
  dynamodb_point_in_time_recovery = true

  # Redis configuration
  redis_node_type                  = var.redis_node_type
  redis_num_cache_clusters         = 3
  redis_automatic_failover_enabled = true
  redis_at_rest_encryption_enabled = true
  redis_transit_encryption_enabled = true

  # Network configuration
  vpc_ids = {
    us_east_1      = length(module.region_us_east_1) > 0 ? module.region_us_east_1[0].vpc_id : ""
    eu_west_1      = length(module.region_eu_west_1) > 0 ? module.region_eu_west_1[0].vpc_id : ""
    ap_northeast_1 = length(module.region_ap_northeast_1) > 0 ? module.region_ap_northeast_1[0].vpc_id : ""
    sa_east_1      = length(module.region_sa_east_1) > 0 ? module.region_sa_east_1[0].vpc_id : ""
  }

  private_subnet_ids = {
    us_east_1      = length(module.region_us_east_1) > 0 ? module.region_us_east_1[0].private_subnet_ids : []
    eu_west_1      = length(module.region_eu_west_1) > 0 ? module.region_eu_west_1[0].private_subnet_ids : []
    ap_northeast_1 = length(module.region_ap_northeast_1) > 0 ? module.region_ap_northeast_1[0].private_subnet_ids : []
    sa_east_1      = length(module.region_sa_east_1) > 0 ? module.region_sa_east_1[0].private_subnet_ids : []
  }

  database_security_group_ids = {
    us_east_1      = length(module.region_us_east_1) > 0 ? module.region_us_east_1[0].database_security_group_id : ""
    eu_west_1      = length(module.region_eu_west_1) > 0 ? module.region_eu_west_1[0].database_security_group_id : ""
    ap_northeast_1 = length(module.region_ap_northeast_1) > 0 ? module.region_ap_northeast_1[0].database_security_group_id : ""
    sa_east_1      = length(module.region_sa_east_1) > 0 ? module.region_sa_east_1[0].database_security_group_id : ""
  }

  redis_security_group_ids = {
    us_east_1      = length(module.region_us_east_1) > 0 ? module.region_us_east_1[0].redis_security_group_id : ""
    eu_west_1      = length(module.region_eu_west_1) > 0 ? module.region_eu_west_1[0].redis_security_group_id : ""
    ap_northeast_1 = length(module.region_ap_northeast_1) > 0 ? module.region_ap_northeast_1[0].redis_security_group_id : ""
    sa_east_1      = length(module.region_sa_east_1) > 0 ? module.region_sa_east_1[0].redis_security_group_id : ""
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "global_accelerator_ips" {
  description = "Global Accelerator IP addresses"
  value       = module.global.global_accelerator_ip_addresses
}

output "global_accelerator_dns" {
  description = "Global Accelerator DNS name"
  value       = module.global.global_accelerator_dns_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.global.ecr_repository_urls
}

output "regional_alb_dns_names" {
  description = "Regional ALB DNS names"
  value = {
    us_east_1      = length(module.region_us_east_1) > 0 ? module.region_us_east_1[0].alb_dns_name : ""
    eu_west_1      = length(module.region_eu_west_1) > 0 ? module.region_eu_west_1[0].alb_dns_name : ""
    ap_northeast_1 = length(module.region_ap_northeast_1) > 0 ? module.region_ap_northeast_1[0].alb_dns_name : ""
    sa_east_1      = length(module.region_sa_east_1) > 0 ? module.region_sa_east_1[0].alb_dns_name : ""
  }
}

output "aurora_endpoint" {
  description = "Aurora primary endpoint"
  value       = module.data.aurora_primary_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = module.data.aurora_primary_reader_endpoint
}

output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = module.data.redis_primary_endpoint
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value = {
    sessions = module.data.dynamodb_sessions_table_name
    orders   = module.data.dynamodb_orders_table_name
    events   = module.data.dynamodb_events_table_name
  }
}
