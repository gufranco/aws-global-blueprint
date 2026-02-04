# =============================================================================
# VPC Endpoints
# =============================================================================
# Private connectivity to AWS services without internet gateway.
# =============================================================================

# -----------------------------------------------------------------------------
# Gateway Endpoints (S3, DynamoDB)
# -----------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints && var.vpc_id != "" ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_vpc_endpoints && var.vpc_id != "" ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-dynamodb-endpoint"
  })
}

# -----------------------------------------------------------------------------
# Interface Endpoints
# -----------------------------------------------------------------------------

locals {
  interface_endpoints = var.enable_vpc_endpoints && var.vpc_id != "" ? [
    "ecr.api",
    "ecr.dkr",
    "ecs",
    "ecs-agent",
    "ecs-telemetry",
    "logs",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "sqs",
    "sns",
    "kms",
    "elasticache",
    "rds",
  ] : []
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoint_security_group_id]
  private_dns_enabled = true

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-${replace(each.value, ".", "-")}-endpoint"
  })
}
