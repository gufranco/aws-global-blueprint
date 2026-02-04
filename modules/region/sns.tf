# =============================================================================
# SNS Topics
# =============================================================================

# -----------------------------------------------------------------------------
# Order Events Topic
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "order_events" {
  name = "${local.name_prefix}-order-events"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-order-events"
    Type = "events"
  })
}

# Subscribe order processing queue to order events
resource "aws_sns_topic_subscription" "order_events_to_sqs" {
  topic_arn            = aws_sns_topic.order_events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.order_processing.arn
  raw_message_delivery = true

  filter_policy = jsonencode({
    eventType = ["order.created", "order.updated", "order.cancelled"]
  })
}

# -----------------------------------------------------------------------------
# Notifications Topic
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "notifications" {
  name = "${local.name_prefix}-notifications"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-notifications"
    Type = "notification"
  })
}

# Subscribe notification queue
resource "aws_sns_topic_subscription" "notifications_to_sqs" {
  topic_arn            = aws_sns_topic.notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notification.arn
  raw_message_delivery = true

  filter_policy = jsonencode({
    notificationType = ["email", "push", "sms"]
  })
}

# -----------------------------------------------------------------------------
# Alerts Topic (for operational alerts)
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-alerts"
    Type = "alerts"
  })
}

# -----------------------------------------------------------------------------
# DLQ Alerts
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.name_prefix}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when DLQ receives messages"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-dlq-alarm"
  })
}
