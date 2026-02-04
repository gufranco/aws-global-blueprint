# =============================================================================
# Compliance Module - Outputs
# =============================================================================

output "cloudtrail_arn" {
  description = "CloudTrail ARN"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "cloudtrail_s3_bucket" {
  description = "CloudTrail S3 bucket name"
  value       = var.enable_cloudtrail && var.cloudtrail_s3_bucket_name == "" ? aws_s3_bucket.cloudtrail[0].id : var.cloudtrail_s3_bucket_name
}

output "config_recorder_id" {
  description = "AWS Config recorder ID"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].id : null
}

output "config_s3_bucket" {
  description = "AWS Config S3 bucket name"
  value       = var.enable_config && var.config_s3_bucket_name == "" ? aws_s3_bucket.config[0].id : var.config_s3_bucket_name
}
