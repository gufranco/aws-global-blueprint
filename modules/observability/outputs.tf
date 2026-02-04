# =============================================================================
# Observability Module - Outputs
# =============================================================================

output "dashboard_name" {
  description = "CloudWatch Dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch Dashboard ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "alarm_arns" {
  description = "Map of alarm names to ARNs"
  value = {
    api_cpu_high     = aws_cloudwatch_metric_alarm.api_cpu_high.arn
    api_memory_high  = aws_cloudwatch_metric_alarm.api_memory_high.arn
    alb_5xx_errors   = aws_cloudwatch_metric_alarm.alb_5xx_errors.arn
    alb_latency_high = aws_cloudwatch_metric_alarm.alb_latency_high.arn
    alb_unhealthy    = aws_cloudwatch_metric_alarm.alb_unhealthy_hosts.arn
    worker_cpu_high  = aws_cloudwatch_metric_alarm.worker_cpu_high.arn
    dlq_messages     = var.sqs_dlq_name != "" ? aws_cloudwatch_metric_alarm.dlq_messages[0].arn : null
  }
}
