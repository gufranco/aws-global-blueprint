# =============================================================================
# AWS Fault Injection Simulator (FIS)
# =============================================================================
# Chaos engineering experiments for resilience testing.
# =============================================================================

# -----------------------------------------------------------------------------
# FIS IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "fis" {
  count = var.enable_fis ? 1 : 0

  name = "${local.name_prefix}-fis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy" "fis" {
  count = var.enable_fis ? 1 : 0

  name = "${local.name_prefix}-fis-policy"
  role = aws_iam_role.fis[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:StopTask"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:RebootInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "rds:FailoverDBCluster",
          "rds:RebootDBInstance"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# FIS Experiment - ECS CPU Stress
# -----------------------------------------------------------------------------

resource "aws_fis_experiment_template" "ecs_cpu_stress" {
  count = var.enable_fis && var.ecs_cluster_arn != "" ? 1 : 0

  description = "Stress test ECS tasks with high CPU"
  role_arn    = aws_iam_role.fis[0].arn

  stop_condition {
    source = "aws:cloudwatch:alarm"
    value  = "arn:aws:cloudwatch:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:alarm:${local.name_prefix}-fis-stop"
  }

  action {
    name        = "cpu-stress"
    action_id   = "aws:ecs:task-cpu-stress"
    description = "Inject CPU stress into ECS tasks"

    parameter {
      key   = "duration"
      value = "PT5M"
    }

    parameter {
      key   = "percent"
      value = "80"
    }

    target {
      key   = "Tasks"
      value = "ecs-tasks"
    }
  }

  target {
    name           = "ecs-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "Project"
      value = var.project_name
    }

    filter {
      path   = "State.Name"
      values = ["RUNNING"]
    }
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-ecs-cpu-stress"
  })
}

# -----------------------------------------------------------------------------
# FIS Experiment - ECS Task Termination
# -----------------------------------------------------------------------------

resource "aws_fis_experiment_template" "ecs_task_termination" {
  count = var.enable_fis && var.ecs_cluster_arn != "" ? 1 : 0

  description = "Terminate ECS tasks to test recovery"
  role_arn    = aws_iam_role.fis[0].arn

  stop_condition {
    source = "none"
  }

  action {
    name        = "stop-tasks"
    action_id   = "aws:ecs:stop-task"
    description = "Stop ECS tasks"

    target {
      key   = "Tasks"
      value = "ecs-tasks"
    }
  }

  target {
    name           = "ecs-tasks"
    resource_type  = "aws:ecs:task"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "Project"
      value = var.project_name
    }

    filter {
      path   = "State.Name"
      values = ["RUNNING"]
    }
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-ecs-task-termination"
  })
}

# -----------------------------------------------------------------------------
# FIS Stop Condition Alarm
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "fis_stop" {
  count = var.enable_fis ? 1 : 0

  alarm_name          = "${local.name_prefix}-fis-stop"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Stop FIS experiment if error rate is too high"
  treat_missing_data  = "notBreaching"

  # This alarm just exists to be used as a stop condition
  # It doesn't need any alarm actions

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-fis-stop"
  })
}
