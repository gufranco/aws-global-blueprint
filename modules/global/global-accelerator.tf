# =============================================================================
# AWS Global Accelerator
# =============================================================================
# Global Accelerator provides static anycast IP addresses that act as a fixed
# entry point to your application, routing traffic to optimal AWS endpoints
# based on health, client location, and policies.
# =============================================================================

# -----------------------------------------------------------------------------
# Global Accelerator
# -----------------------------------------------------------------------------

resource "aws_globalaccelerator_accelerator" "main" {
  count = var.enable_global_accelerator ? 1 : 0

  name            = "${var.project_name}-${var.environment}"
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = var.global_accelerator_flow_logs_enabled
    flow_logs_s3_bucket = var.global_accelerator_flow_logs_bucket != "" ? var.global_accelerator_flow_logs_bucket : null
    flow_logs_s3_prefix = var.global_accelerator_flow_logs_bucket != "" ? "global-accelerator/" : null
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${var.project_name}-${var.environment}-global-accelerator"
  })
}

# -----------------------------------------------------------------------------
# Listener - HTTP (redirects to HTTPS in ALB)
# -----------------------------------------------------------------------------

resource "aws_globalaccelerator_listener" "http" {
  count = var.enable_global_accelerator ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.main[0].id
  protocol        = "TCP"
  client_affinity = "SOURCE_IP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

# -----------------------------------------------------------------------------
# Listener - HTTPS
# -----------------------------------------------------------------------------

resource "aws_globalaccelerator_listener" "https" {
  count = var.enable_global_accelerator ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.main[0].id
  protocol        = "TCP"
  client_affinity = "SOURCE_IP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

# -----------------------------------------------------------------------------
# Endpoint Groups (one per enabled region)
# -----------------------------------------------------------------------------
# Note: Endpoint groups are created dynamically for each enabled region.
# The actual ALB endpoints are added by the region module using the
# aws_globalaccelerator_endpoint_group_endpoint resource.
# -----------------------------------------------------------------------------

resource "aws_globalaccelerator_endpoint_group" "regions" {
  for_each = var.enable_global_accelerator ? local.enabled_regions : {}

  listener_arn                  = aws_globalaccelerator_listener.https[0].id
  endpoint_group_region         = each.value.aws_region
  health_check_interval_seconds = 30
  health_check_path             = "/health"
  health_check_port             = 443
  health_check_protocol         = "HTTPS"
  threshold_count               = 3

  # Traffic dial allows you to control traffic to this region (0-100%)
  # Useful for gradual rollouts or maintenance
  traffic_dial_percentage = 100

  # Port overrides if needed (e.g., if ALB listens on different port)
  # port_override {
  #   endpoint_port = 443
  #   listener_port = 443
  # }
}

# -----------------------------------------------------------------------------
# Cross-Account Resource Sharing (if needed)
# -----------------------------------------------------------------------------
# If your ALBs are in different AWS accounts, you'll need to set up
# cross-account access. This is typically done via:
# 1. Resource-based policies on the ALB
# 2. IAM roles with cross-account trust
# -----------------------------------------------------------------------------
