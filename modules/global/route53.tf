# =============================================================================
# Route53 DNS Configuration
# =============================================================================
# Manages DNS records for the multi-region infrastructure:
# - Hosted zone (optional creation)
# - Health checks for each regional endpoint
# - Failover and latency-based routing records
# =============================================================================

# -----------------------------------------------------------------------------
# Hosted Zone
# -----------------------------------------------------------------------------

resource "aws_route53_zone" "main" {
  count = var.create_hosted_zone && var.domain_name != "" ? 1 : 0

  name    = var.domain_name
  comment = "${var.project_name} ${var.environment} hosted zone"

  tags = merge(local.common_tags, var.tags, {
    Name = "${var.project_name}-${var.environment}-zone"
  })
}

# Use existing hosted zone if not creating new
data "aws_route53_zone" "existing" {
  count = !var.create_hosted_zone && var.existing_hosted_zone_id != "" ? 1 : 0

  zone_id = var.existing_hosted_zone_id
}

locals {
  hosted_zone_id = var.create_hosted_zone ? (
    length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].zone_id : ""
    ) : (
    length(data.aws_route53_zone.existing) > 0 ? data.aws_route53_zone.existing[0].zone_id : ""
  )

  hosted_zone_name = var.create_hosted_zone ? (
    length(aws_route53_zone.main) > 0 ? aws_route53_zone.main[0].name : ""
    ) : (
    length(data.aws_route53_zone.existing) > 0 ? data.aws_route53_zone.existing[0].name : ""
  )
}

# -----------------------------------------------------------------------------
# Health Checks (one per enabled region)
# -----------------------------------------------------------------------------
# These health checks monitor the ALB in each region
# Global Accelerator uses its own health checks, but Route53 health checks
# are useful for DNS failover scenarios
# -----------------------------------------------------------------------------

resource "aws_route53_health_check" "regional" {
  for_each = var.domain_name != "" ? local.enabled_regions : {}

  fqdn              = "alb.${each.value.aws_region}.${var.domain_name}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(local.common_tags, var.tags, {
    Name   = "${var.project_name}-${var.environment}-health-${each.key}"
    Region = each.value.aws_region
  })
}

# -----------------------------------------------------------------------------
# Global Accelerator DNS Record
# -----------------------------------------------------------------------------
# Points the main domain to Global Accelerator's anycast IPs
# -----------------------------------------------------------------------------

resource "aws_route53_record" "global_accelerator" {
  count = var.enable_global_accelerator && local.hosted_zone_id != "" && var.domain_name != "" ? 1 : 0

  zone_id = local.hosted_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_globalaccelerator_accelerator.main[0].dns_name
    zone_id                = aws_globalaccelerator_accelerator.main[0].hosted_zone_id
    evaluate_target_health = true
  }
}

# -----------------------------------------------------------------------------
# Regional ALB Records (for direct regional access)
# -----------------------------------------------------------------------------
# These records allow direct access to specific regional ALBs
# Format: alb.<region>.<domain> (e.g., alb.us-east-1.example.com)
# The actual CNAME/A records are created by the region module
# -----------------------------------------------------------------------------

# Placeholder for regional records - actual records created by region module
# using the hosted_zone_id output from this module

# -----------------------------------------------------------------------------
# Latency-Based Routing (Alternative to Global Accelerator)
# -----------------------------------------------------------------------------
# If not using Global Accelerator, you can use Route53 latency-based routing
# to direct users to the nearest region
# -----------------------------------------------------------------------------

# resource "aws_route53_record" "latency" {
#   for_each = !var.enable_global_accelerator && local.hosted_zone_id != "" ? local.enabled_regions : {}
#
#   zone_id        = local.hosted_zone_id
#   name           = "api.${var.domain_name}"
#   type           = "A"
#   set_identifier = each.key
#
#   latency_routing_policy {
#     region = each.value.aws_region
#   }
#
#   alias {
#     name                   = "alb.${each.value.aws_region}.${var.domain_name}"
#     zone_id                = data.aws_elb_hosted_zone_id.main.id
#     evaluate_target_health = true
#   }
#
#   health_check_id = aws_route53_health_check.regional[each.key].id
# }
