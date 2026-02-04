# =============================================================================
# Security Module - Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# WAF Outputs
# -----------------------------------------------------------------------------

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

# -----------------------------------------------------------------------------
# KMS Outputs
# -----------------------------------------------------------------------------

output "kms_key_id" {
  description = "Main KMS key ID"
  value       = var.enable_kms ? aws_kms_key.main[0].key_id : null
}

output "kms_key_arn" {
  description = "Main KMS key ARN"
  value       = var.enable_kms ? aws_kms_key.main[0].arn : null
}

output "kms_alias_arn" {
  description = "Main KMS alias ARN"
  value       = var.enable_kms ? aws_kms_alias.main[0].arn : null
}

output "secrets_kms_key_id" {
  description = "Secrets Manager KMS key ID"
  value       = var.enable_kms ? aws_kms_key.secrets[0].key_id : null
}

output "secrets_kms_key_arn" {
  description = "Secrets Manager KMS key ARN"
  value       = var.enable_kms ? aws_kms_key.secrets[0].arn : null
}

# -----------------------------------------------------------------------------
# GuardDuty Outputs
# -----------------------------------------------------------------------------

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "guardduty_findings_topic_arn" {
  description = "GuardDuty findings SNS topic ARN"
  value       = var.enable_guardduty ? aws_sns_topic.guardduty_findings[0].arn : null
}

# -----------------------------------------------------------------------------
# Security Hub Outputs
# -----------------------------------------------------------------------------

output "security_hub_findings_topic_arn" {
  description = "Security Hub findings SNS topic ARN"
  value       = var.enable_security_hub ? aws_sns_topic.security_hub_findings[0].arn : null
}

# -----------------------------------------------------------------------------
# VPC Endpoints Outputs
# -----------------------------------------------------------------------------

output "s3_endpoint_id" {
  description = "S3 VPC endpoint ID"
  value       = var.enable_vpc_endpoints && var.vpc_id != "" ? aws_vpc_endpoint.s3[0].id : null
}

output "dynamodb_endpoint_id" {
  description = "DynamoDB VPC endpoint ID"
  value       = var.enable_vpc_endpoints && var.vpc_id != "" ? aws_vpc_endpoint.dynamodb[0].id : null
}

output "interface_endpoint_ids" {
  description = "Interface VPC endpoint IDs"
  value = {
    for name, endpoint in aws_vpc_endpoint.interface : name => endpoint.id
  }
}
