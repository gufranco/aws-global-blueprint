# =============================================================================
# AWS WAF (Web Application Firewall)
# =============================================================================
# Protects against common web exploits with:
# - AWS Managed Rules (OWASP Top 10)
# - Rate limiting per IP
# - Geo blocking
# - Custom IP allow/block lists
# =============================================================================

# -----------------------------------------------------------------------------
# IP Sets
# -----------------------------------------------------------------------------

resource "aws_wafv2_ip_set" "allowed" {
  count = var.enable_waf && length(var.waf_allowed_ips) > 0 ? 1 : 0

  name               = "${local.name_prefix}-allowed-ips"
  description        = "Allowed IP addresses"
  scope              = var.waf_scope
  ip_address_version = "IPV4"
  addresses          = var.waf_allowed_ips

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-allowed-ips"
  })
}

# -----------------------------------------------------------------------------
# Web ACL
# -----------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name        = "${local.name_prefix}-waf"
  description = "WAF for ${var.project_name} ${var.environment}"
  scope       = var.waf_scope

  default_action {
    allow {}
  }

  # ---------------------------------------------------------------------------
  # Rule 1: AWS Managed Rules - Common Rule Set (OWASP)
  # ---------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Exclude rules that might cause false positives
        rule_action_override {
          action_to_use {
            count {}
          }
          name = "SizeRestrictions_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 2: AWS Managed Rules - Known Bad Inputs
  # ---------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 3: AWS Managed Rules - SQL Injection
  # ---------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 4: AWS Managed Rules - Linux OS
  # ---------------------------------------------------------------------------
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-linux"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 5: Rate Limiting
  # ---------------------------------------------------------------------------
  rule {
    name     = "RateLimitRule"
    priority = 10

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate-limit-exceeded"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 6: Geo Blocking (if configured)
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = length(var.waf_blocked_countries) > 0 ? [1] : []

    content {
      name     = "GeoBlockRule"
      priority = 20

      action {
        block {
          custom_response {
            response_code            = 403
            custom_response_body_key = "geo-blocked"
          }
        }
      }

      statement {
        geo_match_statement {
          country_codes = var.waf_blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Rule 7: Allow Listed IPs (if configured)
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = length(var.waf_allowed_ips) > 0 ? [1] : []

    content {
      name     = "AllowListedIPs"
      priority = 0

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.name_prefix}-allow-list"
        sampled_requests_enabled   = true
      }
    }
  }

  # Custom response bodies
  custom_response_body {
    key          = "rate-limit-exceeded"
    content      = jsonencode({ error = { code = "RATE_LIMITED", message = "Too many requests. Please try again later." } })
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "geo-blocked"
    content      = jsonencode({ error = { code = "GEO_BLOCKED", message = "Access denied from your location." } })
    content_type = "APPLICATION_JSON"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-waf"
  })
}

# -----------------------------------------------------------------------------
# WAF Association with ALB
# -----------------------------------------------------------------------------

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enable_waf && var.alb_arn != "" ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# -----------------------------------------------------------------------------
# WAF Logging
# -----------------------------------------------------------------------------

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.main[0].arn

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }

      requirement = "MEETS_ANY"
    }

    filter {
      behavior = "KEEP"

      condition {
        action_condition {
          action = "COUNT"
        }
      }

      requirement = "MEETS_ANY"
    }
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf ? 1 : 0

  # WAF logs require specific naming pattern
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = 30

  tags = merge(local.common_tags, var.tags, {
    Name = "aws-waf-logs-${local.name_prefix}"
  })
}
