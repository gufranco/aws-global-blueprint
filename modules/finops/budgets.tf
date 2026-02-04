# =============================================================================
# AWS Budgets
# =============================================================================

resource "aws_budgets_budget" "monthly" {
  name              = "${local.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  # Alert at each threshold
  dynamic "notification" {
    for_each = var.budget_alert_thresholds

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value > 100 ? "ACTUAL" : "FORECASTED"
      subscriber_email_addresses = var.budget_notification_emails
      subscriber_sns_topic_arns  = var.budget_notification_sns_topic != "" ? [var.budget_notification_sns_topic] : []
    }
  }

  # Actual spend notification
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
    subscriber_sns_topic_arns  = var.budget_notification_sns_topic != "" ? [var.budget_notification_sns_topic] : []
  }

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

# Budget for specific services
resource "aws_budgets_budget" "ecs" {
  name              = "${local.name_prefix}-ecs-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit * 0.4 # 40% of total
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Container Service"]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
    subscriber_sns_topic_arns  = var.budget_notification_sns_topic != "" ? [var.budget_notification_sns_topic] : []
  }

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

resource "aws_budgets_budget" "rds" {
  name              = "${local.name_prefix}-rds-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit * 0.3 # 30% of total
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Service"
    values = ["Amazon Relational Database Service"]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
    subscriber_sns_topic_arns  = var.budget_notification_sns_topic != "" ? [var.budget_notification_sns_topic] : []
  }

  lifecycle {
    ignore_changes = [time_period_start]
  }
}
