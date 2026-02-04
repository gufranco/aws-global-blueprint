# =============================================================================
# AWS Security Hub
# =============================================================================
# Centralized view of security alerts and security posture.
# =============================================================================

# -----------------------------------------------------------------------------
# Security Hub
# -----------------------------------------------------------------------------

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = false
  auto_enable_controls     = true
}

# -----------------------------------------------------------------------------
# Security Hub Standards
# -----------------------------------------------------------------------------

resource "aws_securityhub_standards_subscription" "standards" {
  for_each = var.enable_security_hub ? toset(var.security_hub_standards) : []

  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/${each.value}"

  depends_on = [aws_securityhub_account.main]
}

# -----------------------------------------------------------------------------
# Security Hub Findings to SNS
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "security_hub_findings" {
  count = var.enable_security_hub ? 1 : 0

  name = "${local.name_prefix}-securityhub-findings"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-securityhub-findings"
  })
}

resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  count = var.enable_security_hub ? 1 : 0

  name        = "${local.name_prefix}-securityhub-findings"
  description = "Capture Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
        Workflow = {
          Status = ["NEW"]
        }
      }
    }
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_cloudwatch_event_target" "security_hub_findings" {
  count = var.enable_security_hub ? 1 : 0

  rule      = aws_cloudwatch_event_rule.security_hub_findings[0].name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.security_hub_findings[0].arn
}

resource "aws_sns_topic_policy" "security_hub_findings" {
  count = var.enable_security_hub ? 1 : 0

  arn = aws_sns_topic.security_hub_findings[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchEvents"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_hub_findings[0].arn
      }
    ]
  })
}
