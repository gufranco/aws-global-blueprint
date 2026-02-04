# =============================================================================
# ECS Worker Service
# =============================================================================

# -----------------------------------------------------------------------------
# Task Definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name_prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_worker_cpu
  memory                   = var.ecs_worker_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_worker.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.worker_image
      essential = true

      environment = [
        { name = "NODE_ENV", value = var.environment },
        { name = "AWS_REGION", value = var.aws_region },
        { name = "REGION_KEY", value = var.region_key },
        { name = "IS_PRIMARY_REGION", value = tostring(var.is_primary) },
        { name = "REGION_TIER", value = var.tier },
        { name = "DATABASE_HOST", value = var.database_endpoint },
        { name = "DATABASE_READ_HOST", value = var.database_read_endpoint },
        { name = "DATABASE_PORT", value = tostring(var.database_port) },
        { name = "DATABASE_NAME", value = var.database_name },
        { name = "REDIS_HOST", value = var.redis_endpoint },
        { name = "REDIS_PORT", value = tostring(var.redis_port) },
        { name = "SQS_ORDER_QUEUE_URL", value = aws_sqs_queue.order_processing.url },
        { name = "SQS_NOTIFICATION_QUEUE_URL", value = aws_sqs_queue.notification.url },
        { name = "SQS_DLQ_URL", value = aws_sqs_queue.dlq.url },
        { name = "SNS_ORDER_TOPIC_ARN", value = aws_sns_topic.order_events.arn },
        { name = "SNS_NOTIFICATION_TOPIC_ARN", value = aws_sns_topic.notifications.arn },
      ]

      secrets = var.database_secret_arn != "" ? [
        {
          name      = "DATABASE_URL"
          valueFrom = var.database_secret_arn
        }
      ] : []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.worker.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "node -e 'process.exit(0)'"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-worker-task"
  })
}

# -----------------------------------------------------------------------------
# Service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "worker" {
  name            = "${local.name_prefix}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.ecs_worker_desired

  enable_execute_command = var.ecs_enable_execute_command

  # Use Fargate Spot for workers to reduce costs
  capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
    base              = var.use_fargate_spot ? 0 : 1
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 0
      base              = 1 # Keep at least 1 on-demand task
    }
  }

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_worker.id]
    assign_public_ip = false
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  propagate_tags = "SERVICE"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-worker-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling
# -----------------------------------------------------------------------------

resource "aws_appautoscaling_target" "worker" {
  max_capacity       = var.ecs_worker_max
  min_capacity       = var.ecs_worker_min
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale based on SQS Queue Depth
resource "aws_appautoscaling_policy" "worker_sqs" {
  name               = "${local.name_prefix}-worker-sqs-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 100.0 # messages per task
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Sum"
      unit        = "Count"

      dimensions {
        name  = "QueueName"
        value = aws_sqs_queue.order_processing.name
      }
    }
  }
}

# Scale based on CPU
resource "aws_appautoscaling_policy" "worker_cpu" {
  name               = "${local.name_prefix}-worker-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
