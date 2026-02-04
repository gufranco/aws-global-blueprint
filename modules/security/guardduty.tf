# =============================================================================
# AWS GuardDuty
# =============================================================================
# Threat detection service that continuously monitors for malicious activity
# and unauthorized behavior.
# =============================================================================

# -----------------------------------------------------------------------------
# GuardDuty Detector
# -----------------------------------------------------------------------------

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-guardduty"
  })
}

# -----------------------------------------------------------------------------
# GuardDuty Publishing to SNS
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  name = "${local.name_prefix}-guardduty-findings"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-guardduty-findings"
  })
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  name        = "${local.name_prefix}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", 4] } # Medium and above
      ]
    }
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_cloudwatch_event_target" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "send-to-sns"
  arn       = aws_sns_topic.guardduty_findings[0].arn

  input_transformer {
    input_paths = {
      severity    = "$.detail.severity"
      finding     = "$.detail.type"
      description = "$.detail.description"
      region      = "$.region"
      account     = "$.account"
    }
    input_template = <<EOF
{
  "alarm": "GuardDuty Finding",
  "severity": "<severity>",
  "finding": "<finding>",
  "description": "<description>",
  "region": "<region>",
  "account": "<account>"
}
EOF
  }
}

resource "aws_sns_topic_policy" "guardduty_findings" {
  count = var.enable_guardduty ? 1 : 0

  arn = aws_sns_topic.guardduty_findings[0].arn

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
        Resource = aws_sns_topic.guardduty_findings[0].arn
      }
    ]
  })
}
