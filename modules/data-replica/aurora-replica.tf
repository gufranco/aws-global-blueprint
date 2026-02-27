# =============================================================================
# Aurora Replica Cluster
# =============================================================================
# Read-only replica in a secondary region. Joins the global cluster and
# receives data through Aurora's storage-level replication (typically <1s lag).
# No master_username/master_password: inherited from the global cluster.
# =============================================================================

# -----------------------------------------------------------------------------
# DB Subnet Group (regional)
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "replica" {
  name        = "${local.name_prefix}-${var.region_key}-aurora"
  description = "Aurora subnet group for ${var.region_key} replica"
  subnet_ids  = var.private_subnet_ids

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-${var.region_key}-aurora-subnet-group"
    Region = var.aws_region
  })
}

# -----------------------------------------------------------------------------
# Parameter Groups (must exist in the replica's region)
# -----------------------------------------------------------------------------

resource "aws_rds_cluster_parameter_group" "replica" {
  name        = "${local.name_prefix}-${var.region_key}-aurora-pg15"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 cluster parameters for ${var.region_key}"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-${var.region_key}-aurora-cluster-pg"
  })
}

resource "aws_db_parameter_group" "replica_instance" {
  name        = "${local.name_prefix}-${var.region_key}-aurora-instance-pg15"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 instance parameters for ${var.region_key}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-${var.region_key}-aurora-instance-pg"
  })
}

# -----------------------------------------------------------------------------
# Replica Cluster
# -----------------------------------------------------------------------------

resource "aws_rds_cluster" "replica" {
  cluster_identifier              = "${local.name_prefix}-replica-${var.region_key}"
  global_cluster_identifier       = var.global_cluster_identifier
  engine                          = "aurora-postgresql"
  engine_version                  = var.aurora_engine_version
  db_subnet_group_name            = aws_db_subnet_group.replica.name
  vpc_security_group_ids          = [var.database_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.replica.name

  storage_encrypted = var.aurora_storage_encrypted
  kms_key_id        = var.aurora_kms_key_arn != "" ? var.aurora_kms_key_arn : null

  deletion_protection       = var.aurora_deletion_protection
  skip_final_snapshot       = var.aurora_skip_final_snapshot
  final_snapshot_identifier = var.aurora_skip_final_snapshot ? null : "${local.name_prefix}-${var.region_key}-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_serverless_min_capacity
    max_capacity = var.aurora_serverless_max_capacity
  }

  tags = merge(local.common_tags, var.tags, {
    Name      = "${local.name_prefix}-replica-${var.region_key}"
    Region    = var.aws_region
    IsPrimary = "false"
  })

  lifecycle {
    precondition {
      condition     = var.aurora_serverless_min_capacity <= var.aurora_serverless_max_capacity
      error_message = "aurora_serverless_min_capacity (${var.aurora_serverless_min_capacity}) must be <= aurora_serverless_max_capacity (${var.aurora_serverless_max_capacity})."
    }

    ignore_changes = [
      replication_source_identifier,
      global_cluster_identifier
    ]
  }
}

# -----------------------------------------------------------------------------
# Replica Reader Instances
# -----------------------------------------------------------------------------

resource "aws_rds_cluster_instance" "replica_reader" {
  count = var.aurora_reader_count

  identifier                   = "${local.name_prefix}-${var.region_key}-reader-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.replica.id
  instance_class               = "db.serverless"
  engine                       = aws_rds_cluster.replica.engine
  engine_version               = aws_rds_cluster.replica.engine_version
  db_parameter_group_name      = aws_db_parameter_group.replica_instance.name
  publicly_accessible          = false
  performance_insights_enabled = var.aurora_performance_insights_enabled
  promotion_tier               = 1

  monitoring_interval = var.aurora_enhanced_monitoring_interval
  monitoring_role_arn = var.aurora_enhanced_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-${var.region_key}-reader-${count.index + 1}"
    Region = var.aws_region
    Role   = "reader"
  })
}

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring (regional)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  count = var.aurora_enhanced_monitoring_interval > 0 ? 1 : 0

  name = "${local.name_prefix}-${var.region_key}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.aurora_enhanced_monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
