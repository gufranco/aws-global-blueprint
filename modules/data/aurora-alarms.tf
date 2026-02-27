# =============================================================================
# Aurora Serverless v2 & RDS Proxy - CloudWatch Alarms
# =============================================================================
# Monitors ACU utilization, capacity scaling pressure, and RDS Proxy health.
# Alarms are only created when alarm_sns_topic_arn is provided.
# =============================================================================

locals {
  create_aurora_alarms = var.alarm_sns_topic_arn != ""
}

# -----------------------------------------------------------------------------
# ACU Utilization Alarm (cluster-level)
# -----------------------------------------------------------------------------
# ACUUtilization measures how close the cluster is to its max_capacity.
# High sustained values mean the cluster is under scaling pressure.

resource "aws_cloudwatch_metric_alarm" "aurora_acu_utilization_high" {
  count = local.create_aurora_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-aurora-acu-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ACUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.aurora_acu_alarm_threshold
  alarm_description   = "Aurora Serverless v2 ACU utilization above ${var.aurora_acu_alarm_threshold}% for 15 minutes. Consider increasing aurora_serverless_max_capacity."
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.cluster_identifier
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-aurora-acu-utilization-high"
  })
}

# -----------------------------------------------------------------------------
# ServerlessDatabaseCapacity Alarm (cluster-level)
# -----------------------------------------------------------------------------
# ServerlessDatabaseCapacity tracks actual ACU consumption.
# Alarm fires when capacity stays near max_capacity for sustained periods.

resource "aws_cloudwatch_metric_alarm" "aurora_capacity_near_max" {
  count = local.create_aurora_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-aurora-capacity-near-max"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.aurora_serverless_max_capacity * 0.9
  alarm_description   = "Aurora Serverless v2 capacity at 90%+ of max (${var.aurora_serverless_max_capacity} ACU). Scale ceiling may need adjustment."
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.cluster_identifier
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-aurora-capacity-near-max"
  })
}

# -----------------------------------------------------------------------------
# RDS Proxy - Pinned Connections (proxy-level)
# -----------------------------------------------------------------------------
# Pinned connections bypass connection pooling entirely. Common causes:
# SET statements, temporary tables, prepared statements, advisory locks.
# High pinning negates the pooling benefit of the proxy.

resource "aws_cloudwatch_metric_alarm" "rds_proxy_pinned_connections" {
  count = local.create_aurora_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-proxy-pinned-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnectionsCurrentlySessionPinned"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "RDS Proxy has >10 pinned connections for 15 minutes. Pinned connections bypass pooling. Check for SET statements, temp tables, or prepared statements in the application."
  treat_missing_data  = "notBreaching"

  dimensions = {
    ProxyName = aws_db_proxy.primary.name
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-proxy-pinned-connections"
  })
}

# -----------------------------------------------------------------------------
# RDS Proxy - Connection Pool Saturation (proxy-level)
# -----------------------------------------------------------------------------
# Tracks borrowed connections as a proxy for pool utilization.
# High values mean the pool is under pressure and new requests may queue.

resource "aws_cloudwatch_metric_alarm" "rds_proxy_connections_high" {
  count = local.create_aurora_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-proxy-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "DatabaseConnectionsCurrentlyBorrowed"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 80
  alarm_description   = "RDS Proxy borrowed connections >80 for 15 minutes. Pool may be saturating. Check max_connections_percent and application connection usage."
  treat_missing_data  = "notBreaching"

  dimensions = {
    ProxyName = aws_db_proxy.primary.name
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-proxy-connections-high"
  })
}

# -----------------------------------------------------------------------------
# Aurora Global Database - Replication Lag (cluster-level)
# -----------------------------------------------------------------------------
# Tracks cross-region replication lag for the global database.
# High lag means secondary regions serve increasingly stale data.

resource "aws_cloudwatch_metric_alarm" "aurora_replication_lag" {
  count = local.create_aurora_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-aurora-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "AuroraGlobalDBReplicationLag"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 5000 # 5 seconds
  alarm_description   = "Aurora Global Database replication lag >5s for 15 minutes. Secondary regions are serving stale data. Check network connectivity and primary cluster load."
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.primary.cluster_identifier
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-aurora-replication-lag"
  })
}
